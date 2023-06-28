cluster_name=tap-run

kubectl config use-context $cluster_name

rm sso-authserver-internal.yaml
cat <<EOF | tee sso-authserver-internal.yaml
apiVersion: sso.apps.tanzu.vmware.com/v1alpha1
kind: AuthServer
metadata:
  name: tanzu-authserver-internal
  namespace: default
  labels:
    name: tap-authserver-internal
    env: tutorial
  annotations:
    sso.apps.tanzu.vmware.com/allow-client-namespaces: "default"
    sso.apps.tanzu.vmware.com/allow-unsafe-issuer-uri: ""
    sso.apps.tanzu.vmware.com/allow-unsafe-identity-provider: ""
spec:
  replicas: 1
  tls:
    disabled: true
  identityProviders:
    - name: "internal"
      internalUnsafe:
        users:
          - username: "user"
            password: "password"
            email: "user@example.com"
            emailVerified: true
            roles:
              - "user"
  tokenSignature:
    signAndVerifyKeyRef:
      name: "authserver-signing-key"
---
apiVersion: secretgen.k14s.io/v1alpha1
kind: RSAKey
metadata:
  name: authserver-signing-key
  namespace: default
spec:
  secretTemplate:
    type: Opaque
    stringData:
      key.pem: \$(privateKey)
      pub.pem: \$(publicKey)
EOF

kubectl apply -f sso-authserver-internal.yaml

kubectl wait --for=condition=Ready authserver tanzu-authserver-internal

kubectl get authservers.sso.apps.tanzu.vmware.com --all-namespaces


