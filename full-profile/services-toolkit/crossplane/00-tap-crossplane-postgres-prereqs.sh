export EKS_CLUSTER_NAME=tap-full

kubectl config use-context $EKS_CLUSTER_NAME


# 1. INSTALL CROSSPLANE IN NAMESPACE
kubectl create namespace crossplane-system

helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

helm install crossplane --namespace crossplane-system crossplane-stable/crossplane \
  --set 'args={--enable-external-secret-stores}'


# 2. INSTALL PROVIDER (AWS)
#https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/0.9/svc-tlk/usecases-consuming_aws_rds_with_crossplane.html
#https://docs.crossplane.io/v1.9/getting-started/install-configure/#install-tab-helm3

cat <<EOF | kubectl apply -f -
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
 name: provider-aws
spec:
 package: xpkg.upbound.io/crossplane-contrib/provider-aws:v0.33.0
EOF


# 3. INSTALL PROVIDER CONFIG (SETUPS SECRET FROM AWS CREDENTIALS)
echo -e "[default]\naws_access_key_id = $(aws configure get aws_access_key_id)\naws_secret_access_key = $(aws configure get aws_secret_access_key)\naws_session_token = $(aws configure get aws_session_token)" > creds.conf

kubectl create secret generic aws-provider-creds -n crossplane-system --from-file=creds=./creds.conf

cat <<EOF | kubectl apply -f -
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


# 4. INSTALL COMPOSITE RESOURCE DEFINITION
cat <<EOF | kubectl apply -f -
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


# 5. INSTALL POSTGRES COMPOSITION
cat <<EOF | kubectl apply -f -
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


# 6. CREATE POSTGRES INSTANCE
cat <<EOF | kubectl apply -f -
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

#wait for rds-postgres-db secret to be created when database is finished creating
kubectl get secrets -w


# 7. CREATE SERVICE INSTANCE CLASS THAT WILL MAKE CLAIM AVAILABLE
cat <<EOF | kubectl apply -f -
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

# 8. CREATE SERVICES TOOLKIT ROLE
cat <<EOF | kubectl apply -f -
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


# 9. CREATE RESOURCE CLAIM

#THIS WILL THROW ERROR IF IT'S RUN FOR THE FIRST TIME
tanzu service resource-claim delete rds-claim --yes

#tanzu services claimable list --class rds-postgres

tanzu service resource-claim create rds-claim \
--resource-name rds-postgres-db \
--resource-kind Secret \
--resource-api-version v1

#tanzu services resource-claims get rds-claim --namespace default

tanzu services resource-claims list -o wide


