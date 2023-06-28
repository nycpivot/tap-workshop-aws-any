read -p "AWS Region: " aws_region_code
read -p "EKS Cluster Name: " cluster_name
read -p "RDS Instance Name: " rds_instance

#SETUP ENVIRONMENT (CREATE DBSUBNETGROUP)
#https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/0.7/svc-tlk/GUID-usecases-rds-ack-config_aws_rds_env.html
vpc_id=$(aws eks describe-cluster --name $cluster_name --region $aws_region_code | jq -r .cluster.resourcesVpcConfig.vpcId)
	
subnet1=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${vpc_id}" --region $aws_region_code | jq -r '.Subnets[0] | select(.MapPublicIpOnLaunch == true) | .SubnetId')
subnet2=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=${vpc_id}" --region $aws_region_code | jq -r '.Subnets[1] | select(.MapPublicIpOnLaunch == true) | .SubnetId')

subnet_group_name=tap-rds-subnet-group

rm db-subnet-group.yaml
cat <<EOF | tee db-subnet-group.yaml
# dbsubnetgroup.yaml
---
apiVersion: rds.services.k8s.aws/v1alpha1
kind: DBSubnetGroup
metadata:
  name: $subnet_group_name	
  namespace: ack-system
spec:
  name: $subnet_group_name
  description: $subnet_group_name
  subnetIDs:
  - $subnet1
  - $subnet2
EOF

kubectl apply -f db-subnet-group.yaml

#CHECK
kubectl get DBSubnetGroup -n ack-system $subnet_group_name -o yaml
sleep 5

#GET SECURITY DESCRIPTION OF EKS CLUSTER
security_group_id=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=${vpc_id}" --region $aws_region_code | jq -r '.SecurityGroups[] | select(.Description == "default VPC security group").GroupId')


#CREATE RDS INSTANCE
#https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/0.7/svc-tlk/GUID-usecases-rds-ack-package.html
tanzu package repository add tap-service-reference-packages --url ghcr.io/vmware-tanzu/tanzu-application-platform-reference-packages/tap-service-reference-package-repo:0.0.1 -n tanzu-package-repo-global

rm rds-service-account-installer.yaml
cat <<EOF | tee rds-service-account-installer.yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: rds-install
  namespace: default
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rds-install
  namespace: default
rules:
- apiGroups: ["*"] # TODO: use more fine-grained RBAC permissions
  resources: ["*"]
  verbs: ["*"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: rds-install
  namespace: default
subjects:
- kind: ServiceAccount
  name: rds-install
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: rds-install
EOF

kubectl apply -f rds-service-account-installer.yaml

rm tap-rds-values.yaml
cat <<EOF | tee tap-rds-values.yaml
name: "${rds_instance}"
namespace: "default"
dbSubnetGroupName: "${subnet_group_name}"
vpcSecurityGroupIDs:
- "${security_group_id}"
EOF

tanzu package install $rds_instance --package-name psql.aws.references.services.apps.tanzu.vmware.com --version 0.0.1-alpha --service-account-name rds-install -f tap-rds-values.yaml -n default

#CHECKS
kubectl get DBInstance $rds_instance -n default -o yaml
sleep 5

kubectl get secrettemplate ${rds_instance}-bindable -n default -o jsonpath="{.status.secret.name}"
sleep 5

