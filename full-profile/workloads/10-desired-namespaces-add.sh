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

cluster_name=tap-full
gitops_repo=tap-gitops

cd $HOME/$gitops_repo

pe "vim $HOME/$gitops_repo/clusters/$cluster_name/cluster-config/namespaces/desired-namespaces.yaml"
echo

pe "git add $HOME/$gitops_repo/clusters/$cluster_name/cluster-config/namespaces/desired-namespaces.yaml"
pe "git commit -m 'Added new namespace'"
pe "git push"
echo

pe "kubectl get ns"
echo
