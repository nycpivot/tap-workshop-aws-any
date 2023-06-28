#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-reference-tap-values-build-sample.html

read -p "AWS Region Code: " aws_region_code

cluster_name=tap-build
view_domain=view.tap.nycpivot.com
tap_version=1.4.0

export AWS_ACCOUNT_ID=964978768106
export AWS_REGION=${aws_region_code}


github_token=$(az keyvault secret show --name github-token-nycpivot --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

export AWS_ACCOUNT_ID=964978768106
export AWS_REGION=${aws_region_code}
export TAP_VERSION=1.3.0
export INSTALL_REGISTRY_HOSTNAME=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
export INSTALL_REPO=tap-images

kubectl config use-context $cluster_name

#APPEND GUI SETTINGS
rm tap-values-build-ecr.yaml
cat <<EOF | tee tap-values-build-ecr.yaml
profile: build
ceip_policy_disclosed: true
shared:
  ingress_domain: "${view_domain}"
buildservice:
  kp_default_repository: $INSTALL_REGISTRY_HOSTNAME/tap-build-service
  kp_default_repository_aws_iam_role_arn: "arn:aws:iam::${AWS_ACCOUNT_ID}:role/tap-build-service"
supply_chain: basic
ootb_supply_chain_basic:
  registry:
    server: $INSTALL_REGISTRY_HOSTNAME
    repository: "tanzu-application-platform"
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

tanzu package install tap -p tap.tanzu.vmware.com -v $tap_version --values-file tap-values-build-ecr.yaml -n tap-install

tanzu package installed get tap -n tap-install
sleep 5

tanzu package installed list -A
sleep 5

#tanzu package installed update tap -p tap.tanzu.vmware.com -v 1.3.0 -n tap-install --values-file tap-values-build-ecr.yaml
