#!/bin/bash

read -p "Stack Name (tanzu-operator-stack): " stack_name
read -p "Operator Name (tanzu-operator): " operator_name
read -p "AWS Region Code (us-east-1): " aws_region_code


if [[ -z $stack_name ]]
then
    stack_name=tanzu-operator-stack
fi

if [[ -z $operator_name ]]
then
    operator_name=tanzu-operator
fi

if [[ -z $aws_region_code ]]
then
    aws_region_code=us-east-1
fi

aws cloudformation create-stack \
    --stack-name ${stack_name} \
    --region ${aws_region_code} \
    --parameters ParameterKey=OperatorName,ParameterValue=${operator_name} \
    --template-body file://config/tanzu-operator-stack.yaml

aws cloudformation wait stack-create-complete --stack-name ${stack_name} --region ${aws_region_code}

aws cloudformation describe-stacks \
    --stack-name ${stack_name} \
    --region ${aws_region_code} \
    --query "Stacks[0].Outputs[?OutputKey=='PublicDnsName'].OutputValue" --output text
