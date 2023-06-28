#!/bin/bash

run_cluster_name=tap-run
build_cluster_name=tap-build
app_name=tanzu-java-sso-app
git_app_url=https://github.com/nycpivot/tanzu-java-sso-app

kubectl config use-context $run_cluster_name

rm tanzu-java-sso-claim.yaml
cat <<EOF | tee tanzu-java-sso-claim.yaml
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ResourceClaim
metadata:
  name: tanzu-java-sso-claim
  namespace: default
spec:
  ref:
    apiVersion: sso.apps.tanzu.vmware.com/v1alpha1
    kind: ClientRegistration
    name: tanzu-java-clientregistration-internal
    namespace: default
EOF

kubectl apply -f tanzu-java-sso-claim.yaml

tanzu service claim list -o wide
echo

read -p "Enter Service Ref: " service_ref

#SWITCH TO BUILD CLUSTER
kubectl config use-context $build_cluster_name

tanzu apps workload delete $app_name --yes

tanzu apps workload create ${app_name} \
  --git-repo ${git_app_url} --git-branch main --type web \
  --annotation autoscaling.knative.dev/min-scale=2 --label app.kubernetes.io/part-of=${app_name} \
  --service-ref "tanzu-java-sso-claim=${service_ref}" \
  --yes

tanzu apps workload tail ${app_name} --since 10m --timestamp

