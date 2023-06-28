#!/bin/bash

aws cloudformation create-stack --region $AWS_REGION --stack-name tap-workshop-multicluster-stack \
    --template-body file:///home/ubuntu/tap-workshop/multi-profile/config/tap-multicluster-stack.yaml
