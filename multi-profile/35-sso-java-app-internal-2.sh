#!/bin/bash

run_cluster_name=tap-run
app_name=tanzu-java-sso-app

tanzu apps workload list

tanzu apps workload get ${app_name}

rm ${app_name}-deliverable.yaml
kubectl get deliverable ${app_name} -o yaml | yq 'del(.status)' | yq 'del(.metadata.ownerReferences)' | yq 'del(.metadata.resourceVersion)' | yq 'del(.metadata.uid)' > ${app_name}-deliverable.yaml

#SWITCH TO RUN CLUSTER
kubectl config use-context $run_cluster_name

kubectl apply -f ${app_name}-deliverable.yaml

echo http://${app_name}.default.run.tap.nycpivot.com

