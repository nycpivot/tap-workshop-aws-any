#!/bin/bash

kubectl config get-contexts
echo

read -p "Input cluster name: " cluster_name

kubectl config use-context $cluster_name
echo

GIT_CATALOG_REPOSITORY=tanzu-application-platform

FULL_DOMAIN=$(cat /tmp/tap-full-domain)

# 1. CAPTURE PIVNET SECRETS
export PIVNET_USERNAME=$(az keyvault secret show --name pivnet-username --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
export PIVNET_PASSWORD=$(az keyvault secret show --name pivnet-password --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
export PIVNET_TOKEN=$(az keyvault secret show --name pivnet-token --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

token=$(curl -X POST https://network.pivotal.io/api/v2/authentication/access_tokens -d '{"refresh_token":"'$PIVNET_TOKEN'"}')
access_token=$(echo $token | jq -r .access_token)

curl -i -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X GET https://network.pivotal.io/api/v2/authentication

acr_secret=$(az acr credential show --name tanzuapplicationregistry | jq -r ".passwords[0].value")

export IMGPKG_REGISTRY_HOSTNAME_0=registry.tanzu.vmware.com
export IMGPKG_REGISTRY_USERNAME_0=$PIVNET_USERNAME
export IMGPKG_REGISTRY_PASSWORD_0=$PIVNET_PASSWORD
export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export IMGPKG_REGISTRY_USERNAME_1=tanzuapplicationregistry
export IMGPKG_REGISTRY_PASSWORD_1=$acr_secret
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=$PIVNET_USERNAME
export INSTALL_REGISTRY_PASSWORD=$PIVNET_PASSWORD


#DELETE AND CLONE REPO
#gh auth refresh -h github.com -s delete_repo
#gh repo delete tap-gitops --confirm

rm .ssh/id_ed25519
rm .ssh/id_ed25519.pub
ssh-keygen -t ed25519 -C "ssh@github.com"

#gh repo create tap-gitops --public
#gh repo deploy-key add ~/.ssh/tap-gitops.pub

#COPY PUBLIC KEY INTO DEPLOY KEY IN GITHUB REPO PROJECT
cat .ssh/id_ed25519.pub

read -p "Create new repo" tmp

git clone git@github.com:nycpivot/tap-gitops.git

wget https://network.tanzu.vmware.com/api/v2/products/tanzu-application-platform/releases/1283005/product_files/1467377/download --header="Authorization: Bearer $access_token" -O $HOME/tanzu-gitops-ri-0.1.0.tgz
tar xvf tanzu-gitops-ri-0.1.0.tgz -C $HOME/tap-gitops

rm tanzu-gitops-ri-0.1.0.tgz

cd $HOME/tap-gitops

git add .
git commit -m "Initialize Tanzu GitOps RI"
git push -u origin main


#CREATE CLUSTER CONFIG
./setup-repo.sh $cluster_name sops

git add .
git commit -m "Added tap-full cluster"
git push

cd $HOME

#SETUP AGE
age-keygen -o key.txt

export SOPS_AGE_KEY_FILE=key.txt

cat <<EOF | tee tap-sensitive-values.yaml
tap_install:
 sensitive_values:
EOF

export SOPS_AGE_RECIPIENTS=$(cat $HOME/key.txt | grep "# public key: " | sed 's/# public key: //')
./sops --encrypt $HOME/tap-sensitive-values.yaml > $HOME/tap-sensitive-values.sops.yaml

mv $HOME/tap-sensitive-values.sops.yaml $HOME/tap-gitops/clusters/$cluster_name/cluster-config/values/
rm tap-sensitive-values.yaml

mkdir $HOME/tap-gitops/clusters/$cluster_name/cluster-config/namespaces
rm $HOME/tap-gitops/clusters/$cluster_name/cluster-config/namespaces/desired-namespaces.yaml
cat <<EOF | tee $HOME/tap-gitops/clusters/$cluster_name/cluster-config/namespaces/desired-namespaces.yaml
#@data/values
---
namespaces:
#! The only required parameter is the name of the namespace. All additional values provided here 
#! for a namespace will be available under data.values for templating additional sources
- name: dev
- name: qa
EOF

rm $HOME/tap-gitops/clusters/$cluster_name/cluster-config/namespaces/namespaces.yaml
cat <<EOF | tee $HOME/tap-gitops/clusters/$cluster_name/cluster-config/namespaces/namespaces.yaml
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

rm $HOME/tap-gitops/clusters/$cluster_name/cluster-config/values/tap-non-sensitive-values.yaml
cat <<EOF | tee $HOME/tap-gitops/clusters/$cluster_name/cluster-config/values/tap-non-sensitive-values.yaml
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
        url: https://github.com/nycpivot/tap-gitops.git
    excluded_packages:
      - policy.apps.tanzu.vmware.com
EOF

rm registry-credentials.yaml
cat <<EOF | tee registry-credentials.yaml
tap_install:
 sensitive_values:
   shared:
     image_registry:
       project_path: "$IMGPKG_REGISTRY_HOSTNAME_1/build-service"
       username: "$IMGPKG_REGISTRY_USERNAME_1"
       password: "$IMGPKG_REGISTRY_PASSWORD_1"
EOF

#COPY CONTENTS OF FOLLOWING FILE...
cat registry-credentials.yaml

echo
echo "Copy the above yaml and paste it into editor"
sleep 15

#...AND PASTE IT HERE
./sops $HOME/tap-gitops/clusters/$cluster_name/cluster-config/values/tap-sensitive-values.sops.yaml

export GIT_SSH_PRIVATE_KEY=$(cat $HOME/.ssh/id_ed25519)
export GIT_KNOWN_HOSTS=$(ssh-keyscan github.com)
export SOPS_AGE_KEY=$(cat $HOME/key.txt)
export TAP_PKGR_REPO=registry.tanzu.vmware.com/tanzu-application-platform/tap-packages

cd $HOME/tap-gitops/clusters/$cluster_name

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


# 10. CONFIGURE DNS NAME WITH ELB IP
echo
echo "<<< CONFIGURING DNS >>>"
echo

kubectl get pkgi -n tap-install -w | grep contour

az network dns record-set a delete --name "*.full.tap" --resource-group tanzu-operations --zone-name nycpivot.net --yes
az network dns record-set a create --name "*.full.tap" --resource-group tanzu-operations --zone-name nycpivot.net

#THIS IS NECESSARY DUE TO BUG WITH TTL IN CREATE COMMAND
#https://github.com/Azure/azure-cli/issues/26274
az network dns record-set a update --name "*.full.tap" --resource-group tanzu-operations --zone-name nycpivot.net --set TTL=60

ingress=$(kubectl get svc envoy -n tanzu-system-ingress -o json | jq -r .status.loadBalancer.ingress[].ip)

echo $ingress
echo

az network dns record-set a add-record --ipv4-address $ingress --record-set-name "*.full.tap" \
  --resource-group tanzu-operations --zone-name nycpivot.net --ttl 60

tanzu apps cluster-supply-chain list

echo
echo "TAP-GUI: " https://tap-gui.$FULL_DOMAIN
echo
echo "HAPPY TAP'ING"
echo
