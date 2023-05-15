#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-multicluster-reference-tap-values-view-sample.html

cluster_view=tap-view
cluster_build=tap-build
cluster_run=tap-run
tap_version=1.4.0

target_registry=tanzuapplicationplatform
git_catalog_repository=tanzu-application-platform
view_domain=view.tap.nycpivot.com

pivnet_password=$(az keyvault secret show --name pivnet-registry-secret --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
#github_token=$(az keyvault secret show --name github-token-nycpivot --subscription nycpivot --vault-name tanzuvault --query value --output tsv)

export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=mjames@pivotal.io
export INSTALL_REGISTRY_PASSWORD=$pivnet_password

rm tap-gui-viewer-service-account-rbac.yaml
cat <<EOF | tee tap-gui-viewer-service-account-rbac.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tap-gui
---
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: tap-gui
  name: tap-gui-viewer
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tap-gui-read-k8s
subjects:
- kind: ServiceAccount
  namespace: tap-gui
  name: tap-gui-viewer
roleRef:
  kind: ClusterRole
  name: k8s-reader
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k8s-reader
rules:
- apiGroups: ['']
  resources: ['pods', 'pods/log', 'services', 'configmaps', 'limitranges']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['metrics.k8s.io']
  resources: ['pods']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['apps']
  resources: ['deployments', 'replicasets', 'statefulsets', 'daemonsets']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['autoscaling']
  resources: ['horizontalpodautoscalers']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['networking.k8s.io']
  resources: ['ingresses']
  verbs: ['get', 'watch', 'list']
- apiGroups: ['networking.internal.knative.dev']
  resources: ['serverlessservices']
  verbs: ['get', 'watch', 'list']
- apiGroups: [ 'autoscaling.internal.knative.dev' ]
  resources: [ 'podautoscalers' ]
  verbs: [ 'get', 'watch', 'list' ]
- apiGroups: ['serving.knative.dev']
  resources:
  - configurations
  - revisions
  - routes
  - services
  verbs: ['get', 'watch', 'list']
- apiGroups: ['carto.run']
  resources:
  - clusterconfigtemplates
  - clusterdeliveries
  - clusterdeploymenttemplates
  - clusterimagetemplates
  - clusterruntemplates
  - clustersourcetemplates
  - clustersupplychains
  - clustertemplates
  - deliverables
  - runnables
  - workloads
  verbs: ['get', 'watch', 'list']
- apiGroups: ['source.toolkit.fluxcd.io']
  resources:
  - gitrepositories
  verbs: ['get', 'watch', 'list']
- apiGroups: ['source.apps.tanzu.vmware.com']
  resources:
  - imagerepositories
  - mavenartifacts
  verbs: ['get', 'watch', 'list']
- apiGroups: ['conventions.apps.tanzu.vmware.com']
  resources:
  - podintents
  verbs: ['get', 'watch', 'list']
- apiGroups: ['kpack.io']
  resources:
  - images
  - builds
  verbs: ['get', 'watch', 'list']
- apiGroups: ['scanning.apps.tanzu.vmware.com']
  resources:
  - sourcescans
  - imagescans
  - scanpolicies
  verbs: ['get', 'watch', 'list']
- apiGroups: ['tekton.dev']
  resources:
  - taskruns
  - pipelineruns
  verbs: ['get', 'watch', 'list']
- apiGroups: ['kappctrl.k14s.io']
  resources:
  - apps
  verbs: ['get', 'watch', 'list']
- apiGroups: [ 'batch' ]
  resources: [ 'jobs', 'cronjobs' ]
  verbs: [ 'get', 'watch', 'list' ]
EOF

kubectl config use-context $cluster_build
kubectl apply -f tap-gui-viewer-service-account-rbac.yaml

CLUSTER_URL_BUILD=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_TOKEN_BUILD=$(kubectl -n tap-gui get secret $(kubectl -n tap-gui get sa tap-gui-viewer -o=json \
	| jq -r '.secrets[0].name') -o=json \
	| jq -r '.data["token"]' \
	| base64 --decode)

kubectl config use-context $cluster_run
kubectl apply -f tap-gui-viewer-service-account-rbac.yaml

CLUSTER_URL_RUN=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CLUSTER_TOKEN_RUN=$(kubectl -n tap-gui get secret $(kubectl -n tap-gui get sa tap-gui-viewer -o=json \
	| jq -r '.secrets[0].name') -o=json \
	| jq -r '.data["token"]' \
	| base64 --decode)

kubectl config use-context $cluster_view

#rbac for scst-store displayed in tap-gui
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-tap-gui-plugins-scc-tap-gui.html#enable-cve-scan-results-2
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-scst-store-create-service-account.html#ro-serv-accts
rm metadata-store-service-account-rbac.yaml
cat <<EOF | tee metadata-store-service-account-rbac.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: metadata-store-read-only
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: metadata-store-read-only
subjects:
- kind: ServiceAccount
  name: metadata-store-read-client
  namespace: metadata-store
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: metadata-store-read-client
  namespace: metadata-store
automountServiceAccountToken: false
EOF

kubectl apply -f metadata-store-service-account-rbac.yaml
echo

kubectl get secrets -n metadata-store

read -p "metadata-store-read-client: " read_client

export METADATA_STORE_ACCESS_TOKEN=$(kubectl get secrets ${read_client} -n metadata-store -o jsonpath="{.data.token}" | base64 -d)

rm tap-values-view.yaml
cat <<EOF | tee tap-values-view.yaml
profile: view
ceip_policy_disclosed: true # Installation fails if this is not set to true. Not a string.
shared:
  ingress_domain: "${view_domain}"
tap_gui:
  service_type: ClusterIP
  app_config:
    app:
      baseUrl: http://tap-gui.${view_domain}
    catalog:
      locations:
        - type: url
          target: https://github.com/nycpivot/${git_catalog_repository}/catalog-info.yaml
    backend:
        baseUrl: http://tap-gui.${view_domain}
        cors:
          origin: http://tap-gui.${view_domain}
    kubernetes:
      serviceLocatorMethod:
        type: 'multiTenant'
      clusterLocatorMethods:
        - type: 'config'
          clusters:
            - url: $CLUSTER_URL_BUILD
              name: $cluster_build
              authProvider: serviceAccount
              serviceAccountToken: $CLUSTER_TOKEN_BUILD
              skipTLSVerify: true
            - url: $CLUSTER_URL_RUN
              name: $cluster_run
              authProvider: serviceAccount
              serviceAccountToken: $CLUSTER_TOKEN_RUN
              skipTLSVerify: true
    proxy:
      /metadata-store:
        target: https://metadata-store-app.metadata-store:8443/api/v1
        changeOrigin: true
        secure: false
        headers:
          Authorization: "Bearer ${METADATA_STORE_ACCESS_TOKEN}"
          X-Custom-Source: project-star
contour:
  infrastructure_provider: aws
  envoy:
    service:
      aws:
        LBType: nlb
appliveview:
  sslDisabled: true
  ingressEnabled: true
EOF

tanzu package installed update tap -p tap.tanzu.vmware.com -v $tap_version --values-file tap-values-view.yaml -n tap-install
