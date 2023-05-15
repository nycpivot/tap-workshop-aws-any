#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-reference-tap-values-build-sample.html

cluster_name=tap-build
target_registry=tanzuapplicationplatform
view_domain=view.tap.nycpivot.com
tap_version=1.4.0

pivnet_password=$(az keyvault secret show --name pivnet-registry-secret --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
target_registry_secret=$(az keyvault secret show --name tanzu-application-platform-secret --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
github_token=$(az keyvault secret show --name github-token-nycpivot --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=mjames@pivotal.io
export INSTALL_REGISTRY_PASSWORD=$pivnet_password

kubectl config use-context $cluster_name

#APPEND GUI SETTINGS
rm tap-values-build-acr.yaml
cat <<EOF | tee tap-values-build-acr.yaml
profile: build
ceip_policy_disclosed: true
shared:
  ingress_domain: "${view_domain}"
buildservice:
  kp_default_repository: ${target_registry}.azurecr.io/build-service
  kp_default_repository_username: $target_registry
  kp_default_repository_password: $target_registry_secret
supply_chain: basic
ootb_supply_chain_basic:
  registry:
    server: ${target_registry}.azurecr.io
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

tanzu package install tap -p tap.tanzu.vmware.com -v $tap_version --values-file tap-values-build-acr.yaml -n tap-install

tanzu package installed get tap -n tap-install
sleep 5

tanzu package installed list -A
sleep 5

#tanzu package installed update tap -p tap.tanzu.vmware.com -v 1.3.0 -n tap-install --values-file tap-values-build.yaml
