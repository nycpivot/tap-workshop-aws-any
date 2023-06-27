#!/bin/bash

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
read -p "Database Name (psql-db): " db_name

if [[ -z $namespace ]]
then
    namespace=default
fi

if [[ -z $db_name ]]
then
    db_name=psql-db
fi

app_name=tanzu-bitnami-postgres
git_repo=https://github.com/nycpivot/tanzu-spring-petclinic

pe "kubectl config use-context tap-full"
echo

pe "tanzu service class list"
echo

pe "tanzu service class get postgresql-unmanaged"
echo

pe "tanzu service class-claim create $db_name --class postgresql-unmanaged --parameter storageGB=3 -n $namespace"
echo

pe "kubectl get classclaims -w"
echo

pe "tanzu services class-claims get $db_name --namespace $namespace"
echo

pe "tanzu apps workload list -n $namespace"
echo

workloads_msg=$(tanzu apps workload list)

if [[ $workloads_msg != "No workloads found." ]]
then
    pe "tanzu apps workload delete $app_name -n $namespace --yes"
fi

pe "clear"
echo

pe "tanzu apps workload create $app_name --git-repo $git_repo --git-branch main --type web \
    --label app.kubernetes.io/part-of=$app_name --annotation autoscaling.knative.dev/minScale=1 \
    --env SPRING_PROFILES_ACTIVE=postgres --service-ref db=services.apps.tanzu.vmware.com/v1alpha1:ClassClaim:$db_name --yes"
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



1. These OOTB services, these are in VAC?
1. How do I retain data across workload pod restarts?
2. How to provision an existing database?

