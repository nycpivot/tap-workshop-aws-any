#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-install-aws.html

read -p "AWS Region Code: " aws_region_code

export AWS_ACCOUNT_ID=964978768106
export AWS_REGION=${aws_region_code}
export TAP_VERSION=1.3.0
export INSTALL_REGISTRY_HOSTNAME=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
export INSTALL_REPO=tap-images

aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $INSTALL_REGISTRY_HOSTNAME

imgpkg copy --concurrency 1 -b registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:${TAP_VERSION} --to-repo ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}

#INSTALL TAP PACKAGES
tap_view_cluster=tap-view
tap_build_cluster=tap-build
tap_run_cluster=tap-run

#TAP-INSTALL-VIEW
kubectl config use-context $tap_view_cluster

kubectl create ns tap-install

tanzu package repository add tanzu-tap-repository \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}:$TAP_VERSION \
  --namespace tap-install

sleep 30

tanzu package repository get tanzu-tap-repository --namespace tap-install
sleep 5

tanzu package available list --namespace tap-install
sleep 5

tanzu package available list tap.tanzu.vmware.com --namespace tap-install
sleep 5

#TAP-INSTALL-BUILD
kubectl config use-context $tap_build_cluster

kubectl create ns tap-install

tanzu package repository add tanzu-tap-repository \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}:$TAP_VERSION \
  --namespace tap-install

sleep 30

tanzu package repository get tanzu-tap-repository --namespace tap-install
sleep 5

tanzu package available list --namespace tap-install
sleep 5

tanzu package available list tap.tanzu.vmware.com --namespace tap-install
sleep 5

#TAP-INSTALL-RUN
kubectl config use-context $tap_run_cluster

kubectl create ns tap-install

tanzu package repository add tanzu-tap-repository \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}:$TAP_VERSION \
  --namespace tap-install

sleep 30

tanzu package repository get tanzu-tap-repository --namespace tap-install
sleep 5

tanzu package available list --namespace tap-install
sleep 5

tanzu package available list tap.tanzu.vmware.com --namespace tap-install
sleep 5

#TAP-INSTALL-ITERATE
kubectl config use-context $tap_iterate_cluster

kubectl create ns tap-install

tanzu package repository add tanzu-tap-repository \
  --url ${INSTALL_REGISTRY_HOSTNAME}/${INSTALL_REPO}:$TAP_VERSION \
  --namespace tap-install

sleep 30

tanzu package repository get tanzu-tap-repository --namespace tap-install
sleep 5

tanzu package available list --namespace tap-install
sleep 5

tanzu package available list tap.tanzu.vmware.com --namespace tap-install
sleep 5
