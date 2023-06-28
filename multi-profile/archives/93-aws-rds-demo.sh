read -p "RDS Instance Name: " rds_instance

#https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/0.7/svc-tlk/GUID-usecases-consuming_aws_rds_with_ack.html

kubectl api-resources --api-group rds.services.k8s.aws

rm cluster-instance-class.yaml
cat <<EOF | tee cluster-instance-class.yaml
---
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterInstanceClass
metadata:
  name: aws-rds-postgres
spec:
  description:
    short: AWS RDS instances with a postgresql engine
  pool:
    kind: Secret
    labelSelector:
      matchLabels:
        services.apps.tanzu.vmware.com/class: rds-postgres
EOF

kubectl apply -f cluster-instance-class.yaml

rm stk-secret-reader.yaml
cat <<EOF | tee stk-secret-reader.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: stk-secret-reader
  labels:
    servicebinding.io/controller: "true"
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - list
  - watch
EOF

kubectl apply -f stk-secret-reader.yaml

#rm resource-claim-policy.yaml
#cat <<EOF | tee resource-claim-policy.yaml
#apiVersion: services.apps.tanzu.vmware.com/v1alpha1
#kind: ResourceClaimPolicy
#metadata:
#  name: default-can-claim-rds-postgres
#  #namespace: service-instances #namespace where RDS instance is running
#spec:
#  subject:
#    kind: Secret
#    group: ""
#    selector:
#      matchLabels:
#        services.apps.tanzu.vmware.com/class: rds-postgres
#  consumingNamespaces: [ "default" ]
#EOF

#kubectl apply -f resource-claim-policy.yaml

#CHECKS
tanzu services classes list
sleep 5

tanzu services claimable list --class aws-rds-postgres
sleep 5

tanzu service claim create ack-rds-claim \
  --resource-name ${rds_instance}-bindable \
  --resource-kind Secret \
  --resource-api-version v1

tanzu service claim list -o wide
sleep 5


tanzu apps workload create my-workload \
  --git-repo https://github.com/sample-accelerators/spring-petclinic \
  --git-branch main \
  --git-tag tap-1.2 \
  --type web \
  --label app.kubernetes.io/part-of=spring-petclinic \
  --annotation autoscaling.knative.dev/minScale=1 \
  --env SPRING_PROFILES_ACTIVE=postgres \
  --service-ref db=services.apps.tanzu.vmware.com/v1alpha1:ResourceClaim:ack-rds-claim \
	--yes
