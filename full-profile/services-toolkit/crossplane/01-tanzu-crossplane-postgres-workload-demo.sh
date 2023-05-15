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
TYPE_SPEED=20

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
#DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# hide the evidence
clear

DEMO_PROMPT="${GREEN}➜ TAP ${CYAN}\W "

export APP_NAME=tanzu-crossplane-petclinic
export EKS_CLUSTER_NAME=tap-full
export GIT_APP_URL=https://github.com/nycpivot/tanzu-spring-petclinic

pe "kubectl config use-context $EKS_CLUSTER_NAME"
echo

pe "tanzu apps workload list"
echo

pe "tanzu apps workload delete $APP_NAME --yes"
echo


pe "tanzu services resource-claims list -o wide"
echo

service_ref=$(kubectl get resourceclaim rds-claim -o jsonpath='{.apiVersion}')
claim_name=$(kubectl get resourceclaim rds-claim -o jsonpath='{.metadata.name}')
echo

pe "tanzu apps workload create $APP_NAME --git-repo $GIT_APP_URL --git-branch main --type web --label app.kubernetes.io/part-of=$APP_NAME --annotation autoscaling.knative.dev/minScale=1 --env SPRING_PROFILES_ACTIVE=postgres --service-ref db=${service_ref}:ResourceClaim:${claim_name} --yes"
echo

pe "clear"

pe "tanzu apps workload tail $APP_NAME --since 1h --timestamp"
echo

pe "tanzu apps workload list"
echo

pe "tanzu apps workload get $APP_NAME"
echo


echo http://${APP_NAME}.default.full.tap.nycpivot.com
