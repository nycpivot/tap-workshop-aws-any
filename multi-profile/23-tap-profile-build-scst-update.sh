#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-scst-store-multicluster-setup.html
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-reference-tap-values-build-sample.html

view_cluster_name=tap-view
build_cluster_name=tap-build
target_registry=tanzuapplicationplatform
git_catalog_repository=tanzu-application-platform
view_domain=view.tap.nycpivot.com
tap_version=1.4.0

pivnet_password=$(az keyvault secret show --name pivnet-registry-secret --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
target_registry_secret=$(az keyvault secret show --name tanzu-application-platform-secret --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
github_token=$(az keyvault secret show --name github-token-nycpivot --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=mjames@pivotal.io
export INSTALL_REGISTRY_PASSWORD=$pivnet_password

#CONFIGURE SCST STORE COMMUNICATION
kubectl config use-context $view_cluster_name

CA_CERT=$(kubectl get secret -n metadata-store ingress-cert -o json | jq -r ".data.\"ca.crt\"")
cat <<EOF > scst-ca.yaml
---
apiVersion: v1
kind: Secret
type: Opaque
metadata:
  name: store-ca-cert
  namespace: metadata-store-secrets
data:
  ca.crt: $CA_CERT
EOF

AUTH_TOKEN=$(kubectl get secrets metadata-store-read-write-client -n metadata-store -o jsonpath="{.data.token}" | base64 -d)

#PROCEED TO CREATE BUILD CLUSTER
kubectl config use-context $build_cluster_name

kubectl create ns metadata-store-secrets

kubectl apply -f scst-ca.yaml

kubectl create secret generic store-auth-token \
  --from-literal=auth_token=$AUTH_TOKEN -n metadata-store-secrets

#APPEND GUI SETTINGS
rm tap-values-build.yaml
cat <<EOF | tee tap-values-build.yaml
profile: build
ceip_policy_disclosed: true
shared:
  ingress_domain: "${view_domain}"
buildservice:
  kp_default_repository: ${target_registry}.azurecr.io/build-service
  kp_default_repository_username: $target_registry
  kp_default_repository_password: $target_registry_secret
supply_chain: testing_scanning
ootb_supply_chain_testing_scanning:
  registry:
    server: ${target_registry}.azurecr.io
    repository: "supply-chain"
  gitops:
    ssh_secret: "" # (Optional) Defaults to "".
  cluster_builder: default
  service_account: default
grype:
  metadataStore:
    url: https://metadata-store.${view_domain}
    caSecret:
        name: store-ca-cert
        importFromNamespace: metadata-store-secrets
    authSecret:
        name: store-auth-token
        importFromNamespace: metadata-store-secrets
scanning:
  metadataStore:
    url: "" # Configuration is moved, so set this string to empty.
EOF

tanzu package installed update tap -p tap.tanzu.vmware.com -v $tap_version -n tap-install --values-file tap-values-build.yaml
