#!/bin/bash

read -p "AWS Region Code: " aws_region_code

aws_account_id=964978768106
tap_view_cluster=tap-view
tap_build_cluster=tap-build
tap_run_cluster=tap-run
tap_iterate_cluster=tap-iterate

arn=arn:aws:eks:${aws_region_code}:${aws_account_id}:cluster

aws eks update-kubeconfig --name $tap_view_cluster --region $aws_region_code
aws eks update-kubeconfig --name $tap_build_cluster --region $aws_region_code
aws eks update-kubeconfig --name $tap_run_cluster --region $aws_region_code
aws eks update-kubeconfig --name $tap_iterate_cluster --region $aws_region_code

kubectl config rename-context ${arn}/${tap_view_cluster} $tap_view_cluster
kubectl config rename-context ${arn}/${tap_build_cluster} $tap_build_cluster
kubectl config rename-context ${arn}/${tap_run_cluster} $tap_run_cluster
kubectl config rename-context ${arn}/${tap_iterate_cluster} $tap_iterate_cluster

kubectl config use-context $tap_view_cluster
