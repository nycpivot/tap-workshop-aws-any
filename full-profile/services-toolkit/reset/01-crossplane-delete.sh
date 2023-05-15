export APP_NAME=tanzu-crossplane-petclinic

tanzu service resource-claim delete rds-claim --yes

kubectl delete ClusterRole stk-secret-reader
kubectl delete ClusterInstanceClass rds-postgres
kubectl delete PostgreSQLInstance rds-postgres-db
kubectl delete Composition xpostgresqlinstances.bindable.aws.database.example.org
kubectl delete CompositeResourceDefinition xpostgresqlinstances.bindable.database.example.org
kubectl delete ProviderConfig default
kubectl delete secret aws-provider-creds -n crossplane-system
kubectl delete Provider provider-aws

helm uninstall crossplane -n crossplane-system
helm repo remove crossplane-stable

kubectl delete ns crossplane-system

tanzu apps workload delete $APP_NAME --yes
