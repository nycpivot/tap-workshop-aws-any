#!/bin/bash

export APP_NAME=tanzu-crossplane-petclinic
export EKS_CLUSTER_NAME=tap-full
export GIT_APP_URL=https://github.com/nycpivot/tanzu-spring-petclinic

aws ecr create-repository --repository-name tanzu-application-platform/$APP_NAME-default --region $AWS_REGION --no-cli-pager
aws ecr create-repository --repository-name tanzu-application-platform/$APP_NAME-default-bundle --region $AWS_REGION --no-cli-pager

kubectl config use-context $EKS_CLUSTER_NAME

service_ref=$(kubectl get resourceclaim rds-claim -o jsonpath='{.apiVersion}')
claim_name=$(kubectl get resourceclaim rds-claim -o jsonpath='{.metadata.name}')

tanzu apps workload create ${APP_NAME} \
    --git-repo ${GIT_APP_URL} \
    --git-branch main \
    --type web \
    --label app.kubernetes.io/part-of=${APP_NAME} \
    --annotation autoscaling.knative.dev/minScale=1 \
    --env SPRING_PROFILES_ACTIVE=postgres \
    --service-ref db=${service_ref}:ResourceClaim:${claim_name} --yes
echo

tanzu apps workload tail ${APP_NAME} --since 1h --timestamp
echo

tanzu apps workload list
echo

tanzu apps workload get ${APP_NAME}
echo

echo http://${APP_NAME}.default.full.tap.nycpivot.com
