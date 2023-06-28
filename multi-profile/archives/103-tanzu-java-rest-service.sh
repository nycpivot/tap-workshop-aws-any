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
read -p "Select context: " kube_context

kubectl config use-context $kube_context
echo

#pe "tanzu apps workload delete --all --yes"
#echo

pe "tanzu apps workload list"
echo

#pe "tanzu apps workload create ${app_name} --git-repo ${git_app_url} --git-branch main --type web --label app.kubernetes.io/part-of=${app_name} --yes --dry-run"
#echo

pe "rm ${app_name}-workload.yaml"
echo

pe "wget https://raw.githubusercontent.com/nycpivot/tanzu-java-rest-service/main/config/workload.yaml -O ${app_name}-workload.yaml"
echo

pe "tanzu apps workload create ${app_name} -f ${app_name}-workload.yaml --yes"
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

pe "kubectl get deliverable"
echo

pe "rm ${app_name}-deliverable.yaml"
pe "kubectl get deliverable ${app_name} -o yaml > ${app_name}-deliverable.yaml"
echo

echo "Delete ownerReferences and status sections"

pe "vim ${app_name}-deliverable.yaml"
echo

kubectl config get-contexts
read -p "Select context: " kube_context

kubectl config use-context $kube_context
echo

pe "kubectl apply -f ${app_name}-deliverable.yaml"
echo

pe "kubectl get deliverables"
echo

pe "kubectl get httpproxy"
echo