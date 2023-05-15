#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

########################
# Configure the options
########################

#
# speed at which to simulate typing. bigger num = faster
#
TYPE_SPEED=15

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
#DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# hide the evidence
clear

DEMO_PROMPT="${GREEN}➜ TAP ${CYAN}\W "

read -p "App Name: " app_name
echo

kubectl config get-contexts
echo

read -p "Select build context: " kube_context

git_app_url=https://github.com/nycpivot/${app_name}

kubectl config use-context $kube_context
echo

#pe "tanzu apps workload delete --all --yes"
#echo

pe "tanzu apps workload list"
echo

#pe "tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch main --type web --label app.kubernetes.io/part-of=${app_name} --yes --dry-run"
#echo

pe "tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch main --type web --annotation autoscaling.knative.dev/min-scale=2 --label app.kubernetes.io/part-of=${app_name} --label apps.tanzu.vmware.com/has-tests=true --yes"
echo

pe "clear"

pe "tanzu apps workload tail ${app_name} --since 10m --timestamp"
echo

pe "tanzu apps workload list"
echo

pe "tanzu apps workload get ${app_name}"
echo

#pe "kubectl api-resources | grep knative"
#echo

#kubectl get ksvc

#kubectl get deliverable

#kubectl get services.serving.knative

pe "kubectl get configmaps"
echo

pe "rm ${app_name}-deliverable.yaml"
pe "kubectl get configmap ${app_name}-deliverable -o go-template='{{.data.deliverable}}' > ${app_name}-deliverable.yaml"
#pe "kubectl get configmap ${app_name}-deliverable -o yaml | yq 'del(.metadata.ownerReferences)' | yq 'del(.metadata.resourceVersion)' | yq 'del(.metadata.uid)' > ${app_name}-deliverable.yaml"
echo

kubectl config get-contexts
read -p "Select run context: " kube_context

kubectl config use-context $kube_context
echo

pe "kubectl apply -f ${app_name}-deliverable.yaml"
echo

pe "kubectl get deliverables"
echo

#pe "kubectl get httpproxy"
#echo

echo http://${app_name}.default.run.tap.nycpivot.com
