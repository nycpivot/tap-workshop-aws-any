cluster_name=tap-run

kubectl config use-context $cluster_name

rm sso-authserver-ldap.yaml
cat <<EOF | tee sso-authserver-ldap.yaml
apiVersion: sso.apps.tanzu.vmware.com/v1alpha1
kind: AuthServer
metadata:
  name: tanzu-authserver-ldap
  namespace: default
  labels:
    name: tap-authserver-ldap
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
    - name: ldap
      ldap:
        server:
          scheme: ldap
          host: nycpivot.onmicrosoft.com
          port: 389
          base: ""
        bind:
          dn: uid=binduser,ou=Users,o=07cdb51f-b012-4dc8-893c-6d1a2e5a3c31,dc=nycpivot,dc=onmicrosoft,dc=com
          passwordRef:
            name: ldap-password
        user:
          searchFilter: uid={0}
          searchBase: ou=Users,o=07cdb51f-b012-4dc8-893c-6d1a2e5a3c31,dc=nycpivot,dc=onmicrosoft,dc=com
        group:
          searchFilter: member={0}
          searchBase: ou=Users,o=07cdb51f-b012-4dc8-893c-6d1a2e5a3c31,dc=nycpivot,dc=onmicrosoft,dc=com
          searchSubTree: true
          searchDepth: 10
          roleAttribute: cn
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
---
apiVersion: v1
kind: Secret
metadata:
  name: ldap-password
  namespace: default
stringData:
  password: "P@\$\$w0rd#01"
EOF

kubectl apply -f sso-authserver-ldap.yaml

kubectl wait --for=condition=Ready authserver tanzu-authserver-ldap

kubectl get authservers.sso.apps.tanzu.vmware.com --all-namespaces


