#!/bin/bash

TAP_VERSION=1.5.1
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

#RESET AN EXISTING INSTALLATION
tanzu package installed delete ootb-supply-chain-testing-scanning -n tap-install --yes
tanzu package installed delete ootb-supply-chain-testing -n tap-install --yes
tanzu package installed delete tap -n tap-install --yes

# 8. INSTALL FULL TAP PROFILE
echo
echo "<<< INSTALLING FULL TAP PROFILE >>>"
echo

#GENERATE VALUES
rm tap-values-full-ootb-basic.yaml
cat <<EOF | tee tap-values-full-ootb-basic.yaml
profile: full
ceip_policy_disclosed: true
shared:
  ingress_domain: "$FULL_DOMAIN"
supply_chain: basic
ootb_supply_chain_basic:
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
    url: "metadata-store.$FULL_DOMAIN"
grype:
  namespace: "default"
  targetImagePullSecret: "registry-credentials"
cnrs:
  domain_name: $FULL_DOMAIN
excluded_packages:
  - policy.apps.tanzu.vmware.com
EOF

tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values-full-ootb-basic.yaml -n tap-install
#tanzu package install tap -p tap.tanzu.vmware.com -v $TAP_VERSION --values-file tap-values-full-ootb-basic.yaml -n tap-install --poll-timeout 30m0s
echo


# 9. DEVELOPER NAMESPACE
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.4/tap/scc-ootb-supply-chain-basic.html
echo
echo "<<< CREATING DEVELOPER NAMESPACE >>>"
echo

tanzu secret registry add registry-credentials \
  --server $IMGPKG_REGISTRY_HOSTNAME_1 \
  --username $IMGPKG_REGISTRY_USERNAME_1 \
  --password $IMGPKG_REGISTRY_PASSWORD_1 \
  --namespace default

rm rbac-dev.yaml
cat <<EOF | tee rbac-dev.yaml
apiVersion: v1
kind: Secret
metadata:
  name: tap-registry
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
secrets:
  - name: registry-credentials
imagePullSecrets:
  - name: registry-credentials
  - name: tap-registry
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-deliverable
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deliverable
subjects:
  - kind: ServiceAccount
    name: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-workload
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: workload
subjects:
  - kind: ServiceAccount
    name: default
EOF

kubectl apply -f rbac-dev.yaml


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
