#!/bin/bash

tap_view=tap-view
tap_build=tap-build
tap_run=tap-run
tap_iterate=tap-iterate

arn=arn:aws:eks:$AWS_REGION:$AWS_ACCOUNT_ID:cluster

aws eks update-kubeconfig --name $tap_view --region $AWS_REGION
aws eks update-kubeconfig --name $tap_build --region $AWS_REGION
aws eks update-kubeconfig --name $tap_run --region $AWS_REGION
aws eks update-kubeconfig --name $tap_iterate --region $AWS_REGION

kubectl config rename-context ${arn}/$tap_view $tap_view
kubectl config rename-context ${arn}/$tap_build $tap_build
kubectl config rename-context ${arn}/$tap_run $tap_run
kubectl config rename-context ${arn}/$tap_iterate $tap_iterate

kubectl config use-context $tap_view
