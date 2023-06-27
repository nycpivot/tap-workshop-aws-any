#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-reference-tap-values-view-sample.html

TAP_VERSION=1.5.0
VIEW_DOMAIN=view.tap.nycpivot.com
GIT_CATALOG_REPOSITORY=tanzu-application-platform

# 1. CAPTURE PIVNET SECRETS
export PIVNET_USERNAME=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-username\")
export PIVNET_PASSWORD=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-password\")
export PIVNET_TOKEN=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-token\")

token=$(curl -X POST https://network.pivotal.io/api/v2/authentication/access_tokens -d '{"refresh_token":"'$PIVNET_TOKEN'"}')
access_token=$(echo ${token} | jq -r .access_token)

curl -i -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" \
  -X GET https://network.pivotal.io/api/v2/authentication

acr_secret=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"acr-secret\")

export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export IMGPKG_REGISTRY_USERNAME_1=tanzuapplicationregistry
export IMGPKG_REGISTRY_PASSWORD_1=$acr_secret

tap_build=tap-build

#INSTALL BUILD TAP PROFILE
echo
echo "<<< INSTALLING BUILD TAP PROFILE >>>"
echo

sleep 5

kubectl config use-context $tap_build

rm tap-values-build.yaml
cat <<EOF | tee tap-values-build.yaml
profile: build
ceip_policy_disclosed: true
shared:
  ingress_domain: "$VIEW_DOMAIN"
buildservice:
  kp_default_repository: $IMGPKG_REGISTRY_HOSTNAME_1/build-service
  kp_default_repository_username: $IMGPKG_REGISTRY_USERNAME_1
  kp_default_repository_password: $IMGPKG_REGISTRY_PASSWORD_1
  injected_sidecar_support: true
supply_chain: basic
ootb_supply_chain_basic:
  registry:
    server: $IMGPKG_REGISTRY_HOSTNAME_1
    repository: "supply-chain"
  gitops:
    ssh_secret: "" # (Optional) Defaults to "".
  cluster_builder: default
  service_account: default
grype:
  namespace: "default"
  targetImagePullSecret: "registry-credentials"
scanning:
  metadataStore:
    url: "" # Configuration is moved, so set this string to empty.
EOF

tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values-build.yaml -n tap-install
