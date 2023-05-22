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

read -p "App Namespace (default): " namespace

if [[ -z $namespace ]]
then
    namespace=default
fi

app_name=tanzu-java-web-app
git_repo=https://github.com/nycpivot/tanzu-java-web-app
sub_path=ootb-supply-chain-testing

echo
kubectl config get-contexts
echo

read -p "Select build context: " kube_context

kubectl config use-context $kube_context
echo

#executing these commands this way runs them in the background without showing command
repo1=$(aws ecr delete-repository --repository-name tanzu-application-platform/$app_name-default --region $AWS_REGION --force)
repo2=$(aws ecr delete-repository --repository-name tanzu-application-platform/$app_name-default-bundle --region $AWS_REGION --force)
clear

pe "tanzu apps cluster-supply-chain list"
echo

pe "tanzu apps workload list -n $namespace"
echo

workloads_msg=$(tanzu apps workload list)

if [[ $workloads_msg != "No workloads found." ]]
then
    pe "tanzu apps workload delete $app_name -n $namespace --yes"
    echo
fi
    
pe "clear"
echo

pe "aws ecr create-repository --repository-name tanzu-application-platform/$app_name-default --region $AWS_REGION --no-cli-pager"
echo
pe "aws ecr create-repository --repository-name tanzu-application-platform/$app_name-default-bundle --region $AWS_REGION --no-cli-pager"
echo

pe "clear"

pe "vim $HOME/tanzu-java-web-app/src/main/java/com/example/springboot/HelloController.java"
echo

cd $HOME/tanzu-java-web-app

pe "git add ."
pe "git commit -m 'Created failing test.'"
echo
pe "git push"
echo
cd $HOME

pe "clear"

pe "tanzu apps workload create $app_name -n $namespace --git-repo $git_repo --git-branch main --type web --app $app_name --label apps.tanzu.vmware.com/has-tests=true --param-yaml testing_pipeline_matching_labels='{\"apps.tanzu.vmware.com/pipeline\": \"ootb-supply-chain-testing\"}' --yes"
echo

pe "clear"

pe "tanzu apps workload tail $app_name -n $namespace --since 1h --timestamp"
echo

pe "tanzu apps workload list -n $namespace"
echo

pe "tanzu apps workload get $app_name -n $namespace"
echo

echo "APP URL: " https://$app_name.$namespace.full.tap.nycpivot.com
echo

echo "TAP-GUI: " https://tap-gui.full.tap.nycpivot.com/supply-chain/host/default/$app_name
echo
