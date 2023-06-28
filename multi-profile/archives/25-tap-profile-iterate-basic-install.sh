#!/bin/bash

cluster_name=tap-iterate
target_registry=tanzuapplicationplatform
git_catalog_repository=tanzu-application-platform
iterate_domain=iterate.tap.nycpivot.com
view_domain=view.tap.nycpivot.com
tap_version=1.4.0

pivnet_password=$(az keyvault secret show --name pivnet-registry-secret --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
target_registry_secret=$(az keyvault secret show --name tanzu-application-platform-secret --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
#github_token=$(az keyvault secret show --name github-token-nycpivot --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=mjames@pivotal.io
export INSTALL_REGISTRY_PASSWORD=$pivnet_password

kubectl config use-context $cluster_name

#APPEND GUI SETTINGS
rm tap-values-iterate.yaml
cat <<EOF | tee tap-values-iterate.yaml
profile: iterate
ceip_policy_disclosed: true
shared:
  ingress_domain: $view_domain
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
    ssh_secret: ""
  cluster_builder: default
  service_account: default
image_policy_webhook:
  allow_unmatched_tags: true
contour:
  infrastructure_provider: aws
  envoy:
    service:
      aws:
        LBType: nlb
appliveview_connector:
  backend:
    sslDeactivated: true
    ingressEnabled: true
    host: appliveview.${view_domain}
EOF

tanzu package install tap -p tap.tanzu.vmware.com -v $tap_version --values-file tap-values-iterate.yaml -n tap-install
tanzu package installed get tap -n tap-install
tanzu package installed list -A

kubectl get svc -n tanzu-system-ingress

read -p "Tanzu System Ingress IP: " external_ip

nslookup $external_ip
read -p "IP Address: " ip_address

rm change-iterate-dns.json
cat <<EOF | tee change-iterate-dns.json
{
    "Comment": "Update IP address.",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "*.${iterate_domain}",
                "Type": "A",
                "TTL": 60,
                "ResourceRecords": [
                    {
                        "Value": "${ip_address}"
                    }
                ]
            }
        }
    ]
}
EOF

aws route53 change-resource-record-sets --hosted-zone-id Z0294944QU6R4X4A718M --change-batch file:///$HOME/change-iterate-dns.json
