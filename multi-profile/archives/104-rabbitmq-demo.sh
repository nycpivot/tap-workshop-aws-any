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

pe "kubectl get rabbitmqclusters"
echo

pe "tanzu services instances list -o wide"
echo

read -p "Enter Service Ref: " service_ref

#pe "tanzu apps workload create rmq-sample-app-usecase-1 --git-repo https://github.com/jhvhs/rabbitmq-sample --git-branch v0.1.0 --type web --yes"
#echo

#pe "tanzu apps workload get rmq-sample-app-usecase-1"
#echo

#pe "tanzu apps workload create rmq-sample-app-usecase-2 --git-repo https://github.com/jhvhs/rabbitmq-sample --git-branch v0.1.0 --type web --service-ref 'rmq=rabbitmq.com/v1beta1:RabbitmqCluster:default:example-rabbitmq-cluster-1' --yes --dry-run"
#echo


pe "tanzu apps workload create ${app_name} --git-repo https://github.com/jhvhs/rabbitmq-sample --git-branch v0.1.0 --type web --service-ref 'rmq=${service_ref}' --yes"
echo

pe "tanzu apps workload tail ${app_name} --since 10m --timestamp"
echo

pe "tanzu apps workload get ${app_name}"
echo
