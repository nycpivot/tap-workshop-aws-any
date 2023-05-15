#!/bin/bash

read -p "AWS Region Code: " aws_region_code

aws cloudformation create-stack --region $aws_region_code --stack-name tap-workshop-multicluster-stack --template-body file:///home/ubuntu/tap-workshop/multi-profile/config/tap-multicluster-stack.yaml
