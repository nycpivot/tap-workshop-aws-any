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
 - port: 80 # modification
   containerPort: 8080 # modification
   name: http # modification
 source:
 git:
     url: https://github.com/gm2552/hungryman.git
   ref:
       branch: main
 subPath: hungryman-api-gateway