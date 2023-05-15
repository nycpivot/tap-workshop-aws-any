#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-set-up-namespaces-aws.html
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.4/tap/scc-ootb-supply-chain-basic.html

subscription=nycpivot
target_registry=tanzuapplicationplatform

target_registry_secret=$(az keyvault secret show --name tanzu-application-platform-secret --subscription $subscription --vault-name tanzuvault --query value --output tsv)

kubectl config get-contexts

read -p "Select context: " kube_context

kubectl config use-context $kube_context

tanzu secret registry add registry-credentials --server ${target_registry}.azurecr.io --username "${target_registry}" --password "${target_registry_secret}" --namespace default

#kubectl create secret docker-registry registry-credentials --docker-server="${registry_name}.azurecr.io" --docker-username="${registry_name}" --docker-password="${registry_password}" -n $namespace

cat <<EOF | kubectl -n default apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: tap-registry
  annotations:
    secretgen.carvel.dev/image-pull-secret: ""
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: e30K
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
secrets:
  - name: registry-credentials
imagePullSecrets:
  - name: registry-credentials
  - name: tap-registry
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-deliverable
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deliverable
subjects:
  - kind: ServiceAccount
    name: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: default-permit-workload
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: workload
subjects:
  - kind: ServiceAccount
    name: default
EOF

#kubectl create secret generic git-ssh --from-file=.ssh/git-ssh --from-file=.ssh/git-ssh.pub --from-file=./known_hosts -n tap-install
#kubectl create secret generic git-ssh --from-file=.ssh/git-ssh --from-file=.ssh/git-ssh.pub --from-file=./known_hosts

#GIT-SSH
#1. ssh-keygen -t rsa
#2. vim .ssh/id_rsa.pub -> copy it to the git repo https://github.com/nycpivot/settings/keys
#3. ssh-keyscan github.com > ./known_hosts
#4. kubectl create secret generic git-ssh --from-file=.ssh/git-ssh --from-file=.ssh/git-ssh.pub --from-file=./known_hosts -n tap-install
