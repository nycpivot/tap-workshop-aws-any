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

app_name=tanzu-java-web-app
git_repo=https://github.com/nycpivot/tanzu-java-web-app
sub_path=ootb-supply-chain-testing-scanning

kubectl config get-contexts
echo

read -p "Select build context: " kube_context

kubectl config use-context $kube_context
echo

pe "kubectl edit scanpolicy source-scan-policy"
echo

pe "tanzu apps workload list"
echo

workloads_msg=$(tanzu apps workload list)

if [[ $workloads_msg != "No workloads found." ]]
then
    pe "tanzu apps workload delete $app_name --yes"
    echo
fi

pe "clear"
echo

pe "tanzu apps workload create $app_name --git-repo $git_repo --git-branch main --type web --app $app_name --label apps.tanzu.vmware.com/has-tests=true --param-yaml testing_pipeline_matching_labels='{\"apps.tanzu.vmware.com/pipeline\": \"ootb-supply-chain-testing-scanning\"}' --yes"
echo

pe "clear"

pe "tanzu apps workload tail $app_name --since 1h --timestamp"
echo

pe "tanzu apps workload list"
echo

pe "tanzu apps workload get $app_name"
echo

pe "kubectl get imagescan"
echo

digest=$(kubectl get imagescan -o yaml | yq -r ".items[].spec.registry.image" | awk -F '@' '{print $2}')

pe "tanzu insight image get --digest $digest"
echo

pe "tanzu insight image vulnerabilities --digest $digest"
echo

echo "APP URL: " http://$app_name.default.full.tap.nycpivot.com
echo

echo "TAP-GUI: " https://tap-gui.full.tap.nycpivot.com/supply-chain/host/default/$app_name
echo