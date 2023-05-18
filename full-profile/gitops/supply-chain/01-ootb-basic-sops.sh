#!/bin/bash

echo
kubectl config get-contexts
echo

read -p "Input cluster name: " cluster_name

kubectl config use-context $cluster_name
echo

read -p "GitOps Repository (tap-gitops): " gitops_repo

if [[ -z $gitops_repo ]]
then
  gitops_repo=tap-gitops
fi

GIT_CATALOG_REPOSITORY=tanzu-application-platform

FULL_DOMAIN=$(cat /tmp/tap-full-domain)

# 1. CAPTURE PIVNET SECRETS
export PIVNET_USERNAME=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-username\")
export PIVNET_PASSWORD=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-password\")
export PIVNET_TOKEN=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-token\")

token=$(curl -X POST https://network.pivotal.io/api/v2/authentication/access_tokens -d '{"refresh_token":"'$PIVNET_TOKEN'"}')
access_token=$(echo $token | jq -r .access_token)

curl -i -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $access_token" \
    -X GET https://network.pivotal.io/api/v2/authentication

acr_secret=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"acr-secret\")

export IMGPKG_REGISTRY_HOSTNAME_0=registry.tanzu.vmware.com
export IMGPKG_REGISTRY_USERNAME_0=$PIVNET_USERNAME
export IMGPKG_REGISTRY_PASSWORD_0=$PIVNET_PASSWORD
export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export IMGPKG_REGISTRY_USERNAME_1=tanzuapplicationregistry
export IMGPKG_REGISTRY_PASSWORD_1=$acr_secret
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=$PIVNET_USERNAME
export INSTALL_REGISTRY_PASSWORD=$PIVNET_PASSWORD

#CREATE GIT SSH DEPLOY-KEYS
rm .ssh/id_ed25519
rm .ssh/id_ed25519.pub
ssh-keygen -t ed25519 -C "git@github.com"

#DELETE AND CLONE REPO
rm -rf $gitops_repo

# gh auth refresh -h github.com -s delete_repo
gh auth login --git-protocol ssh --with-token < git-token.txt
gh repo delete $gitops_repo --yes
gh repo create $gitops_repo --public --clone

cd $HOME/$gitops_repo
gh repo deploy-key add ~/.ssh/id_ed25519.pub --allow-write

wget https://network.tanzu.vmware.com/api/v2/products/tanzu-application-platform/releases/1283005/product_files/1467377/download \
  --header="Authorization: Bearer $access_token" -O tanzu-gitops-ri-0.1.0.tgz
tar xvf tanzu-gitops-ri-0.1.0.tgz -C $HOME/$gitops_repo

rm tanzu-gitops-ri-0.1.0.tgz

git add .
git commit -m "Initialize Tanzu GitOps RI"
git branch -m master main
git push -u origin main

#CREATE CLUSTER CONFIG
./setup-repo.sh $cluster_name sops

git add .
git commit -m "Added tap-full cluster"
git push

cd $HOME

mkdir $HOME/$gitops_repo/clusters/$cluster_name/cluster-config/namespaces
rm $HOME/$gitops_repo/clusters/$cluster_name/cluster-config/namespaces/desired-namespaces.yaml
cat <<EOF | tee $HOME/$gitops_repo/clusters/$cluster_name/cluster-config/namespaces/desired-namespaces.yaml
#@data/values
---
namespaces:
#! The only required parameter is the name of the namespace. All additional values provided here 
#! for a namespace will be available under data.values for templating additional sources
- name: dev
- name: qa
EOF

rm $HOME/$gitops_repo/clusters/$cluster_name/cluster-config/namespaces/namespaces.yaml
cat <<EOF | tee $HOME/$gitops_repo/clusters/$cluster_name/cluster-config/namespaces/namespaces.yaml
#@ load("@ytt:data", "data")
#! This for loop will loop over the namespace list in desired-namespaces.yaml and will create those namespaces.
#! NOTE: if you have another tool like Tanzu Mission Control or some other process that is taking care of creating namespaces for you, 
#! and you don’t want namespace provisioner to create the namespaces, you can delete this file from your GitOps install repository.
#@ for ns in data.values.namespaces:
---
apiVersion: v1
kind: Namespace
metadata:
  name: #@ ns.name
#@ end
EOF

rm $HOME/$gitops_repo/clusters/$cluster_name/cluster-config/values/tap-non-sensitive-values.yaml
cat <<EOF | tee $HOME/$gitops_repo/clusters/$cluster_name/cluster-config/values/tap-non-sensitive-values.yaml
---
tap_install:
  values:
    profile: full
    ceip_policy_disclosed: true
    shared:
      ingress_domain: "$FULL_DOMAIN"
    supply_chain: basic
    ootb_supply_chain_basic:
      registry:
        server: $IMGPKG_REGISTRY_HOSTNAME_1
        repository: "supply-chain"
    contour:
      envoy:
        service:
          type: LoadBalancer
    ootb_templates:
      iaas_auth: true
    tap_gui:
      service_type: LoadBalancer
      app_config:
        catalog:
          locations:
            - type: url
              target: https://github.com/nycpivot/$GIT_CATALOG_REPOSITORY/catalog-info.yaml
    metadata_store:
      ns_for_export_app_cert: "default"
      app_service_type: LoadBalancer
    scanning:
      metadataStore:
        url: "metadata-store.$FULL_DOMAIN"
    grype:
      namespace: "default"
      targetImagePullSecret: "registry-credentials"
    cnrs:
      domain_name: $FULL_DOMAIN
    namespace_provisioner:
      controller: false
      gitops_install:
        ref: origin/main
        subPath: clusters/tap-full/cluster-config/namespaces
        url: https://github.com/nycpivot/$gitops_repo.git
    excluded_packages:
      - policy.apps.tanzu.vmware.com
EOF

rm $HOME/key.txt
age-keygen -o $HOME/key.txt

export SOPS_AGE_KEY_FILE=$HOME/key.txt

cat <<EOF | tee tap-sensitive-values.yaml
tap_install:
 sensitive_values:
   shared:
     image_registry:
       project_path: "$IMGPKG_REGISTRY_HOSTNAME_1/build-service"
       username: "$IMGPKG_REGISTRY_USERNAME_1"
       password: "$IMGPKG_REGISTRY_PASSWORD_1"
EOF

export SOPS_AGE_RECIPIENTS=$(cat $HOME/key.txt | grep "# public key: " | sed 's/# public key: //')
sops --encrypt $HOME/tap-sensitive-values.yaml > $HOME/tap-sensitive-values.sops.yaml

mv $HOME/tap-sensitive-values.sops.yaml $HOME/$gitops_repo/clusters/$cluster_name/cluster-config/values/
rm tap-sensitive-values.yaml

#sops $HOME/$gitops_repo/clusters/$cluster_name/cluster-config/values/tap-sensitive-values.sops.yaml

export GIT_SSH_PRIVATE_KEY=$(cat $HOME/.ssh/id_ed25519)
export GIT_KNOWN_HOSTS=$(ssh-keyscan github.com)
export SOPS_AGE_KEY=$(cat $HOME/key.txt)
export TAP_PKGR_REPO=registry.tanzu.vmware.com/tanzu-application-platform/tap-packages

cd $HOME/$gitops_repo/clusters/$cluster_name

./tanzu-sync/scripts/configure.sh

git add cluster-config/ tanzu-sync/
git commit -m "Configure install of TAP 1.5.0"
git push

#INSTALL TAP
./tanzu-sync/scripts/deploy.sh

#SETUP DEVELOPER NAMESPACE CREDENTIALS
tanzu secret registry add registry-credentials \
  --server $IMGPKG_REGISTRY_HOSTNAME_1 \
  --username $IMGPKG_REGISTRY_USERNAME_1 \
  --password $IMGPKG_REGISTRY_PASSWORD_1 \
  --export-to-all-namespaces \
  --namespace tap-install \
  --yes

cd $HOME

#SHOW ALL NS, INCLUDING THOSE ADDED FROM REPO CONFIG
kubectl get ns

# 10. CONFIGURE DNS NAME WITH ELB IP
echo
echo "Press Ctrl+C when contour packages has successfully reconciled"
echo

kubectl get pkgi -n tap-install -w | grep contour

echo
echo "<<< CONFIGURING DNS >>>"
echo

hosted_zone_id=$(aws route53 list-hosted-zones --query HostedZones[0].Id --output text | awk -F '/' '{print $3}')
ingress=$(kubectl get svc envoy -n tanzu-system-ingress -o json | jq -r .status.loadBalancer.ingress[].hostname)
#ip_address=$(nslookup $ingress | awk '/^Address:/ {A=$2}; END {print A}')

echo $ingress
echo

#rm change-batch.json
change_batch_filename=change-batch-$RANDOM
cat <<EOF | tee $change_batch_filename.json
{
    "Comment": "Update record.",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "*.$FULL_DOMAIN",
                "Type": "CNAME",
                "TTL": 60,
                "ResourceRecords": [
                    {
                        "Value": "$ingress"
                    }
                ]
            }
        }
    ]
}
EOF
echo

echo $change_batch_filename.json
aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch file:///$HOME/$change_batch_filename.json

tanzu apps cluster-supply-chain list

echo
echo "TAP-GUI: " https://tap-gui.$FULL_DOMAIN
echo
echo "HAPPY TAP'ING"
echo
