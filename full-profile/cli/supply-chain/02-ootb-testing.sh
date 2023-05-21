#!/bin/bash

TAP_VERSION=1.5.0
GIT_CATALOG_REPOSITORY=tanzu-application-platform

FULL_DOMAIN=$(cat /tmp/tap-full-domain)

# 1. CAPTURE PIVNET SECRETS
export PIVNET_USERNAME=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-username\")
export PIVNET_PASSWORD=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-password\")
export PIVNET_TOKEN=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"pivnet-token\")

token=$(curl -X POST https://network.pivotal.io/api/v2/authentication/access_tokens -d '{"refresh_token":"'$PIVNET_TOKEN'"}')
access_token=$(echo ${token} | jq -r .access_token)

curl -i -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer $access_token" -X GET https://network.pivotal.io/api/v2/authentication

acr_secret=$(aws secretsmanager get-secret-value --secret-id tap-workshop | jq -r .SecretString | jq -r .\"acr-secret\")

export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export IMGPKG_REGISTRY_USERNAME_1=tanzuapplicationregistry
export IMGPKG_REGISTRY_PASSWORD_1=$acr_secret

#INSTALL TAP WITH OOTB TESTING
echo
echo "<<< UPDATE SUPPLY CHAIN TO OOTB TESTING >>>"
echo

rm tap-values-full-ootb-testing.yaml
cat <<EOF | tee tap-values-full-ootb-testing.yaml
profile: full
ceip_policy_disclosed: true
shared:
  ingress_domain: "$FULL_DOMAIN"
supply_chain: testing
ootb_supply_chain_testing:
  registry:
    server: $IMGPKG_REGISTRY_HOSTNAME_1
    repository: "tanzu-application-platform"
buildservice:
  kp_default_repository: $IMGPKG_REGISTRY_HOSTNAME_1/build-service
  kp_default_repository_username: $IMGPKG_REGISTRY_USERNAME_1
  kp_default_repository_password: $IMGPKG_REGISTRY_PASSWORD_1
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
    url: ""
grype:
  namespace: "default"
  targetImagePullSecret: "registry-credentials"
cnrs:
  domain_name: $FULL_DOMAIN
excluded_packages:
  - policy.apps.tanzu.vmware.com
EOF
echo

tanzu package installed update tap -v $TAP_VERSION --values-file tap-values-full-ootb-testing.yaml -n tap-install


#CONFIGURE DNS NAME WITH ELB IP
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


#CREATE TEKTON PIPELINE
kubectl delete -f pipeline-testing.yaml

rm pipeline-testing.yaml
cat <<'EOF' | tee pipeline-testing.yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: tanzu-java-web-app-pipeline
  labels:
    apps.tanzu.vmware.com/pipeline: ootb-supply-chain-testing      # (!) required
spec:
  params:
    - name: source-url                        # (!) required
    - name: source-revision                   # (!) required
  tasks:
    - name: test
      params:
        - name: source-url
          value: $(params.source-url)
        - name: source-revision
          value: $(params.source-revision)
      taskSpec:
        params:
          - name: source-url
          - name: source-revision
        steps:
          - name: test
            image: gradle
            securityContext:
              runAsUser: 0
            script: |-
              cd `mktemp -d`
              wget -qO- $(params.source-url) | tar xvz -m
              chmod +x ./mvnw
              ./mvnw test
EOF
echo

kubectl apply -f pipeline-testing.yaml

tanzu apps cluster-supply-chain list

echo
echo "TAP-GUI: " https://tap-gui.$FULL_DOMAIN
echo
echo "HAPPY TAP'ING"
echo
