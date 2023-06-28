#!/bin/bash

kubectl config use-context tap-build

rm hungryman-workload.yaml
cat <<EOF | tee hungryman-workload.yaml
apiVersion: carto.run/v1alpha1
kind: Workload
metadata:
  name: hungryman
  labels:
    apps.tanzu.vmware.com/workload-type: server # modification
    app.kubernetes.io/part-of: hungryman-api-gateway
spec:
  params:
  - name: ports # modification
    value:
    - name: http # modification
      port: 80 # modification
      containerPort: 8080 # modification
  source:
    git:
      url: https://github.com/gm2552/hungryman.git
      ref:
        branch: main
      subPath: hungryman-api-gateway
EOF
 
tanzu apps workload apply --file hungryman-workload.yaml
