#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-reference-tap-values-view-sample.html

TAP_VERSION=1.5.0
VIEW_DOMAIN=view.tap.nycpivot.com
RUN_DOMAIN=run.tap.nycpivot.com

# 1. CAPTURE PIVNET SECRETS
export PIVNET_USERNAME=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-username\")
export PIVNET_PASSWORD=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-password\")
export PIVNET_TOKEN=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-token\")

token=$(curl -X POST https://network.pivotal.io/api/v2/authentication/access_tokens -d '{"refresh_token":"'$PIVNET_TOKEN'"}')
access_token=$(echo ${token} | jq -r .access_token)

curl -i -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" \
  -X GET https://network.pivotal.io/api/v2/authentication

tap_run=tap-run

#INSTALL RUN TAP PROFILE
echo
echo "<<< INSTALLING RUN TAP PROFILE >>>"
echo

sleep 5

kubectl config use-context $tap_run

rm tap-values-run.yaml
cat <<EOF | tee tap-values-run.yaml
profile: run
ceip_policy_disclosed: true
shared:
  ingress_domain: $RUN_DOMAIN
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
    host: appliveview.$VIEW_DOMAIN
excluded_packages:
  - policy.apps.tanzu.vmware.com
EOF

tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values-run.yaml -n tap-install
