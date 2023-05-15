#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-reference-tap-values-run-sample.html

cluster_name=tap-run
run_domain=run.tap.nycpivot.com
view_domain=view.tap.nycpivot.com
tap_version=1.4.0

pivnet_password=$(az keyvault secret show --name pivnet-registry-secret --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=mjames@pivotal.io
export INSTALL_REGISTRY_PASSWORD=$pivnet_password

kubectl config use-context $cluster_name

#APPEND GUI SETTINGS
rm tap-values-run.yaml
cat <<EOF | tee tap-values-run.yaml
profile: run
ceip_policy_disclosed: true
shared:
  ingress_domain: $run_domain
supply_chain: basic
contour:
  infrastructure_provider: aws
  envoy:
    service:
      aws:
        LBType: nlb
appliveview_connector:
  backend:
    sslDisabled: true
    ingressEnabled: true
    host: appliveview.${view_domain}
excluded_packages:
  - policy.apps.tanzu.vmware.com
EOF

tanzu package install tap -p tap.tanzu.vmware.com -v $tap_version --values-file tap-values-run.yaml -n tap-install --poll-timeout 30m0s

tanzu package installed get tap -n tap-install
sleep 5

tanzu package installed list -A
sleep 5

kubectl get svc -n tanzu-system-ingress

read -p "Tanzu System Ingress IP: " external_ip

nslookup $external_ip
read -p "IP Address: " ip_address

rm change-run-dns.json
cat <<EOF | tee change-run-dns.json
{
    "Comment": "Update IP address.",
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "*.${run_domain}",
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

aws route53 change-resource-record-sets --hosted-zone-id Z0294944QU6R4X4A718M --change-batch file:///$HOME/change-run-dns.json

kubectl edit configmap config-autoscaler -n knative-serving
#enable-scale-to-zero: "false"
#initial-scale: "2"

#tanzu package installed update tap -p tap.tanzu.vmware.com -v $tap_version -n tap-install --values-file tap-values-run.yaml
#kubectl get pkgi <PACKAGE-INSTALL-NAME> -n tap-install -o yaml
