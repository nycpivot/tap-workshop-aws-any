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
- apiGroups: ["*"]
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

rm rds-instance-values.yaml
cat <<EOF | tee rds-instance-values.yaml
name: "tanzu-rds"
namespace: "default"
dbSubnetGroupName: "tanzu-rds-subnet-group"
vpcSecurityGroupIDs:
- "sg-0aaf2bc0571a5b9da"
EOF

tanzu package install tanzu-rds --package-name psql.aws.references.services.apps.tanzu.vmware.com --version 0.0.1-alpha --service-account-name rds-install -f rds-instance-values.yaml -n default

kubectl get DBInstance tanzu-rds -n default -o yaml
kubectl get secrettemplate tanzu-rds-bindable -n default -o jsonpath="{.status.secret.name}"
