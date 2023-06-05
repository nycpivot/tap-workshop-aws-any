#!/bin/bash

export TANZU_CLI_NO_INIT=true
export TANZU_VERSION=v0.28.1
export TAP_VERSION=1.5.0

export CLI_FILENAME=tanzu-framework-linux-amd64-v0.28.1.1.tar
export ESSENTIALS_FILENAME=tanzu-cluster-essentials-linux-amd64-1.5.0.tgz

export PIVNET_USERNAME=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-username\")
export PIVNET_PASSWORD=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-password\")
export PIVNET_TOKEN=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-token\")

token=$(curl -X POST https://network.pivotal.io/api/v2/authentication/access_tokens -d '{"refresh_token":"'$PIVNET_TOKEN'"}')
access_token=$(echo $token | jq -r .access_token)

curl -i -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $access_token" \
    -X GET https://network.pivotal.io/api/v2/authentication

tap_view=tap-view
tap_build=tap-build
tap_run=tap-run
tap_iterate=tap-iterate

VIEW_DOMAIN=view.tap.nycpivot.com


# 1. CREATE CLUSTERS
echo
echo "<<< CREATING CLUSTERS >>>"
echo

sleep 5

  aws cloudformation create-stack --stack-name tap-multicluster-stack --region $AWS_REGION \
      --template-body file:///home/ubuntu/tap-workshop-aws-any/multi-profile/config/tap-multicluster-stack-$AWS_REGION.yaml
  aws cloudformation wait stack-create-complete --stack-name tap-multicluster-stack --region $AWS_REGION

arn=arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster

aws eks update-kubeconfig --name $tap_view --region $AWS_REGION
aws eks update-kubeconfig --name $tap_build --region $AWS_REGION
aws eks update-kubeconfig --name $tap_run --region $AWS_REGION
aws eks update-kubeconfig --name $tap_iterate --region $AWS_REGION

kubectl config rename-context ${arn}/$tap_view $tap_view
kubectl config rename-context ${arn}/$tap_build $tap_build
kubectl config rename-context ${arn}/$tap_run $tap_run
kubectl config rename-context ${arn}/$tap_iterate $tap_iterate

kubectl config use-context $tap_view


#CONFIGURE CLUSTERS
clusters=( $tap_view $tap_build $tap_run $tap_iterate )

for cluster in "${clusters[@]}" ; do

    # 2. INSTALL CSI PLUGIN (REQUIRED FOR K8S 1.23+)
    echo
    echo "<<< INSTALLING CSI PLUGIN ($cluster) >>>"
    echo

    sleep 5

    kubectl config use-context $cluster

    rolename=${cluster}-csi-driver-role

    aws eks create-addon \
      --cluster-name $cluster \
      --addon-name aws-ebs-csi-driver \
      --service-account-role-arn "arn:aws:iam::$AWS_ACCOUNT_ID:role/$rolename"

    #https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
    aws eks describe-cluster --name $cluster --query "cluster.identity.oidc.issuer" --output text

    #https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
    oidc_id=$(aws eks describe-cluster --name $cluster --query "cluster.identity.oidc.issuer" --output text | awk -F '/' '{print $5}')
    echo "OIDC Id: $oidc_id"

    # Check if a IAM OIDC provider exists for the cluster
    # https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
    if [[ -z $(aws iam list-open-id-connect-providers | grep $oidc_id) ]]; then
      echo "Creating IAM OIDC provider"
      if ! [ -x "$(command -v eksctl)" ]; then
        echo "Error `eksctl` CLI is required, https://eksctl.io/introduction/#installation" >&2
        exit 1
      fi

      eksctl utils associate-iam-oidc-provider --cluster $cluster --approve
    fi

cat <<EOF | tee aws-ebs-csi-driver-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/oidc.eks.$AWS_REGION.amazonaws.com/id/$oidc_id"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.$AWS_REGION.amazonaws.com/id/$oidc_id:aud": "sts.amazonaws.com",
          "oidc.eks.$AWS_REGION.amazonaws.com/id/$oidc_id:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
}
EOF

    aws iam create-role \
      --role-name $rolename \
      --assume-role-policy-document file://"aws-ebs-csi-driver-trust-policy.json" \
      --no-cli-pager
      
    aws iam attach-role-policy \
      --role-name $rolename \
      --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
      --no-cli-pager
      
    kubectl annotate serviceaccount ebs-csi-controller-sa \
        eks.amazonaws.com/role-arn=arn:aws:iam::$AWS_ACCOUNT_ID:role/$rolename \
        -n kube-system --overwrite

    rm aws-ebs-csi-driver-trust-policy.json
    
    echo


    # 3. DOWNLOAD AND INSTALL TANZU CLI AND ESSENTIALS
    # https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/install-tanzu-cli.html
    # https://network.tanzu.vmware.com/products/tanzu-application-platform#/releases/1287438/file_groups/12507
    echo
    echo "<<< INSTALLING TANZU CLI AND CLUSTER ESSENTIALS >>>"
    echo

    sleep 5

    export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
    export INSTALL_REGISTRY_USERNAME=$PIVNET_USERNAME
    export INSTALL_REGISTRY_PASSWORD=$PIVNET_PASSWORD
    export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:79abddbc3b49b44fc368fede0dab93c266ff7c1fe305e2d555ed52d00361b446

    rm -rf $HOME/tanzu
    mkdir $HOME/tanzu

    wget https://network.pivotal.io/api/v2/products/tanzu-application-platform/releases/1295414/product_files/1478717/download \
        --header="Authorization: Bearer $access_token" -O $HOME/tanzu/$CLI_FILENAME
    tar -xvf $HOME/tanzu/$CLI_FILENAME -C $HOME/tanzu

    cd tanzu

    sudo install cli/core/$TANZU_VERSION/tanzu-core-linux_amd64 /usr/local/bin/tanzu

    tanzu plugin install --local cli all

    cd $HOME

    # 4. DOWNLOAD AND INSTALL CLUSTER ESSENTIALS
    # https://docs.vmware.com/en/Cluster-Essentials-for-VMware-Tanzu/1.5/cluster-essentials/deploy.html
    # https://network.tanzu.vmware.com/products/tanzu-cluster-essentials/
    echo
    echo "<<< INSTALLING TANZU CLUSTER ESSENTIALS >>>"
    echo

    sleep 5

    rm -rf $HOME/tanzu-cluster-essentials
    mkdir $HOME/tanzu-cluster-essentials

    wget https://network.pivotal.io/api/v2/products/tanzu-cluster-essentials/releases/1275537/product_files/1460876/download \
        --header="Authorization: Bearer $access_token" -O $HOME/tanzu-cluster-essentials/$ESSENTIALS_FILENAME
    tar -xvf $HOME/tanzu-cluster-essentials/$ESSENTIALS_FILENAME -C $HOME/tanzu-cluster-essentials

    cd $HOME/tanzu-cluster-essentials

    ./install.sh --yes

    sudo cp $HOME/tanzu-cluster-essentials/kapp /usr/local/bin/kapp
    sudo cp $HOME/tanzu-cluster-essentials/imgpkg /usr/local/bin/imgpkg

    cd $HOME

    rm $HOME/tanzu/$CLI_FILENAME
    rm $HOME/tanzu-cluster-essentials/$ESSENTIALS_FILENAME
done


# 5. IMPORT TAP PACKAGES
echo
echo "<<< IMPORTING TAP PACKAGES >>>"
echo

sleep 5

acr_secret=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"acr-secret\")

export IMGPKG_REGISTRY_HOSTNAME_0=registry.tanzu.vmware.com
export IMGPKG_REGISTRY_USERNAME_0=$PIVNET_USERNAME
export IMGPKG_REGISTRY_PASSWORD_0=$PIVNET_PASSWORD
export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export IMGPKG_REGISTRY_USERNAME_1=tanzuapplicationregistry
export IMGPKG_REGISTRY_PASSWORD_1=$acr_secret
export INSTALL_REPO=tanzu-application-platform/tap-packages

docker login $IMGPKG_REGISTRY_HOSTNAME_0 -u $IMGPKG_REGISTRY_USERNAME_0 -p $IMGPKG_REGISTRY_PASSWORD_0

imgpkg copy --concurrency 1 -b $IMGPKG_REGISTRY_HOSTNAME_0/tanzu-application-platform/tap-packages:${TAP_VERSION} \
    --to-repo ${IMGPKG_REGISTRY_HOSTNAME_1}/$INSTALL_REPO

for cluster in "${clusters[@]}" ; do

    kubectl config use-context $cluster

    # 6. INSTALL TAP WITH CLI
    echo
    echo "<<< INSTALLING TAP WITH CLI >>>"
    echo

    sleep 5

    kubectl create ns tap-install

    tanzu secret registry add tap-registry \
      --username $IMGPKG_REGISTRY_USERNAME_1 \
      --password $IMGPKG_REGISTRY_PASSWORD_1 \
      --server $IMGPKG_REGISTRY_HOSTNAME_1 \
      --export-to-all-namespaces --yes --namespace tap-install

    tanzu package repository add tanzu-tap-repository \
      --url $IMGPKG_REGISTRY_HOSTNAME_1/$INSTALL_REPO:$TAP_VERSION \
      --namespace tap-install

    tanzu package repository get tanzu-tap-repository --namespace tap-install
done

kubectl config use-context $tap_view


#download sample app code
rm -rf tanzu-java-web-app
git clone https://github.com/nycpivot/tanzu-java-web-app


#INSTALL OOTB SUPPLY CHAIN - BASIC
#bash $HOME/tap-workshop-aws-any/multi-profile/cli/supply-chain/01-ootb-basic-view.sh
#bash $HOME/tap-workshop-aws-any/multi-profile/cli/supply-chain/01-ootb-basic-build.sh
#bash $HOME/tap-workshop-aws-any/multi-profile/cli/supply-chain/01-ootb-basic-run.sh
#bash $HOME/tap-workshop-aws-any/multi-profile/cli/supply-chain/01-ootb-basic-iterate.sh

echo
echo "TAP-GUI: " https://tap-gui.$VIEW_DOMAIN
echo
echo "HAPPY TAP'ING"
echo
