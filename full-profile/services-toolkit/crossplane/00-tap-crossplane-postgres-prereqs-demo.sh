#!/bin/bash

########################
# include the magic
########################
. demo-magic.sh

########################
# Configure the options
########################

#
# speed at which to simulate typing. bigger num = faster
#
TYPE_SPEED=20

#
# custom prompt
#
# see http://www.tldp.org/HOWTO/Bash-Prompt-HOWTO/bash-prompt-escape-sequences.html for escape sequences
#
#DEMO_PROMPT="${GREEN}➜ ${CYAN}\W "

# hide the evidence
clear

DEMO_PROMPT="${GREEN}➜ HELM ${CYAN}\W "

kubectl config use-context tap-full
echo

#INSTALL CROSSPLANE IN NAMESPACE
pe "kubectl create namespace crossplane-system"
echo

pe "helm repo add crossplane-stable https://charts.crossplane.io/stable"
echo

pe "helm repo update"
echo

pe "helm install crossplane --namespace crossplane-system crossplane-stable/crossplane --set 'args={--enable-external-secret-stores}'"
echo

pe "clear"

DEMO_PROMPT="${GREEN}➜ CROSSPLANE ${CYAN}\W "

#INSTALL AWS PROVIDER
rm provider-aws.yaml
cat <<EOF | tee provider-aws.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
 name: provider-aws
spec:
 package: xpkg.upbound.io/crossplane-contrib/provider-aws:v0.33.0
EOF
echo

pe "kubectl apply -f provider-aws.yaml"
echo

#kubectl get provider.pkg.crossplane.io provider-aws

#EXTRACT AWS CREDS TO CREATE A FILE, USED TO CREATE A SECRET THAT PROVIDER CONFIG BELOW WILL BE ABLE TO USE TO CREATE RESOURCES
echo -e "[default]\naws_access_key_id = $(aws configure get aws_access_key_id)\naws_secret_access_key = $(aws configure get aws_secret_access_key)\naws_session_token = $(aws configure get aws_session_token)" > creds.conf

pe "kubectl create secret generic aws-provider-creds -n crossplane-system --from-file=creds=./creds.conf"
echo

rm -f creds.conf

rm provider-config.yaml
cat <<EOF | tee provider-config.yaml
apiVersion: aws.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
 name: default
spec:
 credentials:
   source: Secret
   secretRef:
     namespace: crossplane-system
     name: aws-provider-creds
     key: creds
EOF
echo

pe "kubectl apply -f provider-config.yaml"
echo

rm xrd.yaml
cat <<EOF | tee xrd.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
 name: xpostgresqlinstances.bindable.database.example.org
spec:
 claimNames:
   kind: PostgreSQLInstance
   plural: postgresqlinstances
 connectionSecretKeys:
 - type
 - provider
 - host
 - port
 - database
 - username
 - password
 group: bindable.database.example.org
 names:
   kind: XPostgreSQLInstance
   plural: xpostgresqlinstances
 versions:
 - name: v1alpha1
   referenceable: true
   schema:
     openAPIV3Schema:
       properties:
         spec:
           properties:
             parameters:
               properties:
                 storageGB:
                   type: integer
               required:
               - storageGB
               type: object
           required:
           - parameters
           type: object
       type: object
   served: true
EOF
echo

pe "kubectl apply -f xrd.yaml"
echo

rm composition.yaml
cat <<EOF | tee composition.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
 labels:
   provider: "aws"
   vpc: "default"
 name: xpostgresqlinstances.bindable.aws.database.example.org
spec:
 compositeTypeRef:
   apiVersion: bindable.database.example.org/v1alpha1
   kind: XPostgreSQLInstance
 publishConnectionDetailsWithStoreConfigRef:
   name: default
 resources:
 - base:
     apiVersion: database.aws.crossplane.io/v1beta1
     kind: RDSInstance
     spec:
       forProvider:
         dbInstanceClass: db.t2.micro
         engine: postgres
         dbName: postgres
         engineVersion: "12"
         masterUsername: masteruser
         publiclyAccessible: true
         region: $AWS_REGION
         skipFinalSnapshotBeforeDeletion: true
       writeConnectionSecretToRef:
         namespace: crossplane-system
   connectionDetails:
   - name: type
     value: postgresql
   - name: provider
     value: aws
   - name: database
     value: postgres
   - fromConnectionSecretKey: username
   - fromConnectionSecretKey: password
   - name: host
     fromConnectionSecretKey: endpoint
   - fromConnectionSecretKey: port
   name: rdsinstance
   patches:
   - fromFieldPath: metadata.uid
     toFieldPath: spec.writeConnectionSecretToRef.name
     transforms:
     - string:
         fmt: '%s-postgresql'
         type: Format
       type: string
     type: FromCompositeFieldPath
   - fromFieldPath: spec.parameters.storageGB
     toFieldPath: spec.forProvider.allocatedStorage
     type: FromCompositeFieldPath
EOF
echo

pe "kubectl apply -f composition.yaml"
echo

#pe "aws rds describe-db-instances --region ${aws_region_code}"
#echo

#CREATE RDS DATABASE INSTANCE HERE (WILL BE VISIBLE IN CONSOLE)
rm postgres.yaml
cat <<EOF | tee postgres.yaml
apiVersion: bindable.database.example.org/v1alpha1
kind: PostgreSQLInstance
metadata:
 name: rds-postgres-db
 namespace: default
spec:
 parameters:
   storageGB: 20
 compositionSelector:
   matchLabels:
     provider: aws
     vpc: default
 publishConnectionDetailsTo:
   name: rds-postgres-db
   metadata:
     labels:
       services.apps.tanzu.vmware.com/class: rds-postgres
EOF
echo

pe "kubectl apply -f postgres.yaml"
echo

#WAIT FOR rds-postgres-db to be created when database is finished creating
kubectl get secrets -w
echo

pe "kubectl get secret rds-postgres-db -o yaml"
echo

pe "kubectl get secret rds-postgres-db -o jsonpath='{.data.host}' | base64 --decode"
echo

pe "kubectl get secret rds-postgres-db -o jsonpath='{.data.password}' | base64 --decode"
echo

#pe "aws rds describe-db-instances --region ${aws_region_code} | jq [.DBInstances[].Endpoint.Address]"
#echo

pe "clear"

DEMO_PROMPT="${GREEN}➜ TANZU ${CYAN}\W "

#CREATE SERVICE INSTANCE CLASS, TO MAKE AVAILABLE TO MAKE CLAIM
rm postgres-instance.yaml
cat <<EOF | tee postgres-instance.yaml
apiVersion: services.apps.tanzu.vmware.com/v1alpha1
kind: ClusterInstanceClass
metadata:
  name: rds-postgres
spec:
  description:
    short: AWS RDS Postgresql database instances
  pool:
    kind: Secret
    labelSelector:
      matchLabels:
        services.apps.tanzu.vmware.com/class: rds-postgres
    fieldSelector: type=connection.crossplane.io/v1alpha1
EOF
echo

pe "kubectl apply -f postgres-instance.yaml"

#rm stk-role.yaml
kubectl apply -f -<<EOF
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
echo

pe "tanzu service classes list"
echo

#tanzu services claimable list --class rds-postgres

pe "tanzu service resource-claim create rds-claim --resource-name rds-postgres-db --resource-kind Secret --resource-api-version v1"
echo

#tanzu services resource-claims get rds-claim --namespace default

pe "tanzu services resource-claims list -o wide"
echo


