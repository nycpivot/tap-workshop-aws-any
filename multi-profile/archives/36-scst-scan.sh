#!/bin/bash

#docs
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-scst-scan-samples-public-source-compliance.html

view_cluster_name=tap-view
build_cluster_name=tap-build

kubectl config use-context $build_cluster_name

rm scst-public-source-scan-with-compliance-check.yaml
cat <<EOF | tee scst-public-source-scan-with-compliance-check.yaml
---
apiVersion: scanning.apps.tanzu.vmware.com/v1beta1
kind: ScanPolicy
metadata:
  name: sample-scan-policy
  labels:
    'app.kubernetes.io/part-of': 'enable-in-gui'
spec:
  regoFile: |
    package main

    # Accepted Values: "Critical", "High", "Medium", "Low", "Negligible", "UnknownSeverity"
    notAllowedSeverities := ["Critical"]
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

---
apiVersion: scanning.apps.tanzu.vmware.com/v1beta1
kind: SourceScan
metadata:
  name: sample-public-source-scan-with-compliance-check
spec:
  git:
    url: "https://github.com/houndci/hound.git"
    revision: "5805c650"
  scanTemplate: public-source-scan-template
  scanPolicy: sample-scan-policy
EOF

#watch kubectl get scantemplates,scanpolicies,sourcescans,imagescans,pods,jobs

kubectl apply -f scst-public-source-scan-with-compliance-check.yaml

kubectl describe sourcescan sample-public-source-scan-with-compliance-check

#configure tanzu insights (on view cluster)
kubectl config use-context $view_cluster_name

kubectl get secret ingress-cert -n metadata-store -o json | jq -r '.data."ca.crt"' | base64 -d > insight-ca.crt

METADATA_STORE_DOMAIN="metadata-store.view.tap.nycpivot.com"

tanzu insight config set-target https://$METADATA_STORE_DOMAIN --ca-cert insight-ca.crt

export METADATA_STORE_ACCESS_TOKEN=$(kubectl get secrets metadata-store-read-write-client -n metadata-store -o jsonpath="{.data.token}" | base64 -d)

read -p "Commit Id: " commit_id

tanzu insight source get --commit $commit_id

#troubleshooting
#kubectl logs scan-sample-public-source-scan-with-compliance-check-fz8g5hccm7 -c metadata-store-plugin
#kubectl describe sourcescan.scanning.apps.tanzu.vmware.com/sample-public-source-scan-with-compliance-check


