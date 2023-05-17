#!/bin/bash

cluster_name=tap-full

#DELETE IAM CSI DRIVER ROLE
rolename=$cluster_name-csi-driver-role

aws iam detach-role-policy \
    --role-name ${rolename} \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --no-cli-pager

aws iam delete-role --role-name ${rolename}

#DELETE IAM ECR POLICIES & ROLES
aws iam delete-role-policy --role-name tap-build-service --policy-name tapBuildServicePolicy --no-cli-pager
aws iam delete-role-policy --role-name tap-workload --policy-name tapWorkload --no-cli-pager

aws iam delete-role --role-name tap-build-service --no-cli-pager
aws iam delete-role --role-name tap-workload --no-cli-pager

#DELETE ELBs
classic_lb1=$(aws elb describe-load-balancers | jq -r .LoadBalancerDescriptions[0].LoadBalancerName)
classic_lb2=$(aws elb describe-load-balancers | jq -r .LoadBalancerDescriptions[1].LoadBalancerName)
#network_lb=$(aws elbv2 describe-load-balancers | jq -r .LoadBalancers[].LoadBalancerArn)

aws elb delete-load-balancer --load-balancer-name $classic_lb1
aws elb delete-load-balancer --load-balancer-name $classic_lb2
#aws elbv2 delete-load-balancer --load-balancer-arn $network_lb

sleep 60

#DELETE IGWs
#aws ec2 describe-internet-gateways --no-cli-pager

#DELETE ECRs
aws ecr delete-repository --repository-name tanzu-application-platform/tanzu-java-web-app-default --region $AWS_REGION --force
aws ecr delete-repository --repository-name tanzu-application-platform/tanzu-java-web-app-default-bundle --region $AWS_REGION --force

#aws ecr delete-repository --repository-name tap-images --region $AWS_REGION --force
#aws ecr delete-repository --repository-name tap-build-service --region $AWS_REGION --force

#DELETE VPC

#DELETE STACK
eksctl delete cluster --name $cluster_name

rm .kube/config


#--- EXPERIMENTAL ---
#aws cloudformation delete-stack --stack-name tap-workshop-singlecluster-stack --region $AWS_REGION
#aws cloudformation wait stack-delete-complete --stack-name tap-workshop-singlecluster-stack --region $AWS_REGION

#vpc_id=$(aws ec2 describe-vpcs --query "Vpcs[?Tags[?Value=='tap-workshop-singlecluster-vpc']].VpcId" --output text)

#aws ec2 delete-vpc --vpc-id $vpc_id --force
#aws ec2 wait delete-vpc --vpc-id $vpc_id --force

#aws cloudformation delete-stack --stack-name tap-workshop-singlecluster-stack --region $AWS_REGION
#aws cloudformation wait stack-delete-complete --stack-name tap-workshop-singlecluster-stack --region $AWS_REGION



#hosted_zones_count=$(aws route53 get-hosted-zone-count | jq .HostedZoneCount)
#hosted_zones=$(aws route53 list-hosted-zones | jq -r .HostedZones)
#hosted_zones_count=$(echo $hosted_zones | jq length)

#index=0
#while [ $index -lt ${hosted_zones_count} ]
#do
#  hosted_zone_name=$(aws route53 list-hosted-zones | jq -r .HostedZones[$index].Name)
#  counter=`expr $index + 1`
#  index=`expr $index + 1`
  
#  echo "$counter) $hosted_zone_name"
#done


#vpc="vpc-xxxxxxxxxxxxx" 
#aws ec2 describe-internet-gateways --filters 'Name=attachment.vpc-id,Values='$vpc | grep InternetGatewayId
#aws ec2 describe-subnets --filters 'Name=vpc-id,Values='$vpc | grep SubnetId
#aws ec2 describe-route-tables --filters 'Name=vpc-id,Values='$vpc | grep RouteTableId
#aws ec2 describe-network-acls --filters 'Name=vpc-id,Values='$vpc | grep NetworkAclId
#aws ec2 describe-vpc-peering-connections --filters 'Name=requester-vpc-info.vpc-id,Values='$vpc | grep VpcPeeringConnectionId
#aws ec2 describe-vpc-endpoints --filters 'Name=vpc-id,Values='$vpc | grep VpcEndpointId
#aws ec2 describe-nat-gateways --filter 'Name=vpc-id,Values='$vpc | grep NatGatewayId
#aws ec2 describe-security-groups --filters 'Name=vpc-id,Values='$vpc | grep GroupId
#aws ec2 describe-instances --filters 'Name=vpc-id,Values='$vpc | grep InstanceId
#aws ec2 describe-vpn-connections --filters 'Name=vpc-id,Values='$vpc | grep VpnConnectionId
#aws ec2 describe-vpn-gateways --filters 'Name=attachment.vpc-id,Values='$vpc | grep VpnGatewayId
#aws ec2 describe-network-interfaces --filters 'Name=vpc-id,Values='$vpc | grep NetworkInterfaceId
