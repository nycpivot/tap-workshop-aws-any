#!/bin/bash

tap_view=tap-view
tap_build=tap-build
tap_run=tap-run
tap_iterate=tap-iterate

#DELETE IAM CSI DRIVER ROLE
view_rolename=$tap_view-csi-driver-role
build_rolename=$tap_build-csi-driver-role
run_rolename=$tap_run-csi-driver-role
iterate_rolename=$tap_iterate-csi-driver-role

aws iam detach-role-policy \
    --role-name $view_rolename \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --no-cli-pager

aws iam detach-role-policy \
    --role-name $build_rolename \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --no-cli-pager

aws iam detach-role-policy \
    --role-name $run_rolename \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --no-cli-pager

aws iam detach-role-policy \
    --role-name $iterate_rolename \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --no-cli-pager

aws iam delete-role --role-name $view_rolename
aws iam delete-role --role-name $build_rolename
aws iam delete-role --role-name $run_rolename
aws iam delete-role --role-name $iterate_rolename

aws cloudformation delete-stack --stack-name tap-multicluster-stack --region $AWS_REGION
aws cloudformation wait stack-delete-complete --stack-name tap-multicluster-stack --region $AWS_REGION

rm .kube/config
