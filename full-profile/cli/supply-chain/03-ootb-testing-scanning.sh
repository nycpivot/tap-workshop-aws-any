#!/bin/bash

TAP_VERSION=1.5.0

OOTB_SUPPLY_CHAIN_TESTING_SCANNING_VERSION=0.12.5

SOURCE_SCAN_POLICY=source-scan-policy
IMAGE_SCAN_POLICY=image-scan-policy
SCAN_TEMPLATE_SOURCE=blob-source-scan-template
SCAN_TEMPLATE_IMAGE=private-image-scan-template

FULL_DOMAIN=$(cat /tmp/tap-full-domain)

#CREATE SOURCE SCAN POLICY
rm source-scan-policy.yaml
cat <<EOF | tee source-scan-policy.yaml
apiVersion: scanning.apps.tanzu.vmware.com/v1beta1
kind: ScanPolicy
metadata:
  name: $SOURCE_SCAN_POLICY
  labels:
    'app.kubernetes.io/part-of': 'enable-in-gui'
spec:
  regoFile: |
    package main

    # Accepted Values: "Critical", "High", "Medium", "Low", "Negligible", "UnknownSeverity"
    notAllowedSeverities := ["Critical", "High", "UnknownSeverity"]
    ignoreCves := []

    contains(array, elem) = true {
      array[_] = elem
    } else = false { true }

    isSafe(match) {
      severities := { e | e := match.ratings.rating.severity } | { e | e := match.ratings.rating[_].severity }
      some i
      fails := contains(notAllowedSeverities, severities[i])
      not fails
    }

    isSafe(match) {
      ignore := contains(ignoreCves, match.id)
      ignore
    }

    deny[msg] {
      comps := { e | e := input.bom.components.component } | { e | e := input.bom.components.component[_] }
      some i
      comp := comps[i]
      vulns := { e | e := comp.vulnerabilities.vulnerability } | { e | e := comp.vulnerabilities.vulnerability[_] }
      some j
      vuln := vulns[j]
      ratings := { e | e := vuln.ratings.rating.severity } | { e | e := vuln.ratings.rating[_].severity }
      not isSafe(vuln)
      msg = sprintf("CVE %s %s %s", [comp.name, vuln.id, ratings])
    }
EOF
echo

#CREATE IMAGE SCAN POLICY
rm image-scan-policy.yaml
cat <<EOF | tee image-scan-policy.yaml
apiVersion: scanning.apps.tanzu.vmware.com/v1beta1
kind: ScanPolicy
metadata:
  name: $IMAGE_SCAN_POLICY
  labels:
    'app.kubernetes.io/part-of': 'enable-in-gui'
spec:
  regoFile: |
    package main

    # Accepted Values: "Critical", "High", "Medium", "Low", "Negligible", "UnknownSeverity"
    notAllowedSeverities := ["Critical", "High", "UnknownSeverity"]
    ignoreCves := []

    contains(array, elem) = true {
      array[_] = elem
    } else = false { true }

    isSafe(match) {
      severities := { e | e := match.ratings.rating.severity } | { e | e := match.ratings.rating[_].severity }
      some i
      fails := contains(notAllowedSeverities, severities[i])
      not fails
    }

    isSafe(match) {
      ignore := contains(ignoreCves, match.id)
      ignore
    }

    deny[msg] {
      comps := { e | e := input.bom.components.component } | { e | e := input.bom.components.component[_] }
      some i
      comp := comps[i]
      vulns := { e | e := comp.vulnerabilities.vulnerability } | { e | e := comp.vulnerabilities.vulnerability[_] }
      some j
      vuln := vulns[j]
      ratings := { e | e := vuln.ratings.rating.severity } | { e | e := vuln.ratings.rating[_].severity }
      not isSafe(vuln)
      msg = sprintf("CVE %s %s %s", [comp.name, vuln.id, ratings])
    }
EOF
echo

kubectl apply -f source-scan-policy.yaml
kubectl apply -f image-scan-policy.yaml


#UPDATE TAP WITH OOTB TESTING & SCANNING
echo
echo "<<< UPDATE SUPPLY CHAIN TO OOTB TESTING & SCANNING >>>"
echo

export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export IMGPKG_REGISTRY_HOSTNAME_1=tanzuapplicationregistry.azurecr.io
export IMGPKG_REGISTRY_USERNAME_1=tanzuapplicationregistry
export IMGPKG_REGISTRY_PASSWORD_1=$acr_secret

rm tap-values-full-ootb-testing-scanning.yaml
cat <<EOF | tee tap-values-full-ootb-testing-scanning.yaml
registry:
  server: $IMGPKG_REGISTRY_HOSTNAME_1
  repository: "tanzu-application-platform"
scanning:
  source:
    policy: $SOURCE_SCAN_POLICY
    template: $SCAN_TEMPLATE_SOURCE
  image:
    policy: $IMAGE_SCAN_POLICY
    template: $SCAN_TEMPLATE_IMAGE
grype:
  namespace: "default"
  targetImagePullSecret: "registry-credentials"
  scanner:
    serviceAccount: grype-scanner
EOF
echo

tanzu package install ootb-supply-chain-testing-scanning \
  --package ootb-supply-chain-testing-scanning.tanzu.vmware.com \
  --version $OOTB_SUPPLY_CHAIN_TESTING_SCANNING_VERSION \
  --values-file tap-values-full-ootb-testing-scanning.yaml \
  -n tap-install


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

#CONFIGURE INSIGHTS
rm /tmp/tap-metadata-store.crt
kubectl get secret ingress-cert -n metadata-store -o json | jq -r '.data."ca.crt"' | base64 -d > /tmp/tap-metadata-store.crt

tanzu insight config set-target https://metadata-store.$FULL_DOMAIN --ca-cert /tmp/tap-metadata-store.crt

export METADATA_STORE_ACCESS_TOKEN=$(kubectl get secrets metadata-store-read-write-client -n metadata-store -o jsonpath="{.data.token}" | base64 -d)

tanzu insight health


#CREATE TEKTON PIPELINE
kubectl delete -f pipeline-testing.yaml

rm pipeline-testing.yaml
cat <<'EOF' | tee pipeline-testing.yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: tanzu-java-web-app-pipeline
  labels:
    apps.tanzu.vmware.com/pipeline: ootb-supply-chain-testing-scanning      # (!) required
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

tanzu insight config set-target http://localhost:8443

tanzu apps cluster-supply-chain list

echo
echo "TAP-GUI: " https://tap-gui.$FULL_DOMAIN
echo
echo "HAPPY TAP'ING"
echo
