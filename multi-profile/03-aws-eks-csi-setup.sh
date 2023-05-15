#!/bin/bash
#https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html
#https://docs.aws.amazon.com/eks/latest/userguide/csi-iam-role.html
#https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html

read -p "AWS Region Code: " aws_region_code

account_id=964978768106
cluster_view=tap-view
cluster_build=tap-build
cluster_run=tap-run
cluster_iterate=tap-iterate

clusters=( $cluster_view $cluster_build $cluster_run $cluster_iterate )

for cluster in "${clusters[@]}" ; do
    echo $cluster

    kubectl config use-context $cluster

    rolename=${cluster}-csi-driver-role

    aws iam detach-role-policy \
      --role-name ${rolename} \
      --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
      
    aws iam delete-role \
      --role-name ${rolename}

    #https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html
    #INSTALL CSI DRIVER PLUGIN (REQUIRED FOR K8S 1.23)
    aws eks delete-addon \
      --cluster-name $cluster \
      --addon-name aws-ebs-csi-driver

    aws eks create-addon \
      --cluster-name $cluster \
      --addon-name aws-ebs-csi-driver \
      --service-account-role-arn "arn:aws:iam::${account_id}:role/${rolename}"

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

rm aws-ebs-csi-driver-trust-policy.json
cat <<EOF | tee aws-ebs-csi-driver-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${account_id}:oidc-provider/oidc.eks.${aws_region_code}.amazonaws.com/id/${oidc_id}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "oidc.eks.${aws_region_code}.amazonaws.com/id/${oidc_id}:aud": "sts.amazonaws.com",
          "oidc.eks.${aws_region_code}.amazonaws.com/id/${oidc_id}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
        }
      }
    }
  ]
}
EOF

    aws iam create-role \
      --role-name $rolename \
      --assume-role-policy-document file://"aws-ebs-csi-driver-trust-policy.json"
      
    aws iam attach-role-policy \
      --role-name $rolename \
      --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
      
    kubectl annotate serviceaccount ebs-csi-controller-sa \
        -n kube-system --overwrite \
        eks.amazonaws.com/role-arn=arn:aws:iam::${account_id}:role/${rolename}
    
    echo
done
