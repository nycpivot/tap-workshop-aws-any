#!/bin/bash

read -p "AWS Region Code (us-east-1): " aws_region_code

if [[ -z $aws_region_code ]]
then
    aws_region_code=us-east-1
fi

aws cloudformation create-stack --stack-name tanzu-single-cluster-operator-stack --region $aws_region_code \
    --template-body file://config/tanzu-single-cluster-operator-stack.yaml

aws cloudformation wait stack-create-complete --stack-name tanzu-single-cluster-operator-stack --region $aws_region_code

aws cloudformation describe-stacks --stack-name tanzu-single-cluster-operator-stack --region $aws_region_code \
    --query "Stacks[0].Outputs[?OutputKey=='PublicDnsName'].OutputValue" --output text
