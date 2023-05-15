cluster_name=tap-run

kubectl config use-context $cluster_name

rm sso-java-clientregistration-internal.yaml
cat <<EOF | tee sso-java-clientregistration-internal.yaml
apiVersion: sso.apps.tanzu.vmware.com/v1alpha1
kind: ClientRegistration
metadata:
   name: tanzu-java-clientregistration-internal
   namespace: default
spec:
   authServerSelector:
      matchLabels:
         name: tap-authserver-internal
         env: tutorial
   redirectURIs:
      - "http://tanzu-java-sso-app.default.run.tap.nycpivot.com/login/oauth2/code/tanzu-java-sso-claim"
   requireUserConsent: true
   clientAuthenticationMethod: basic
   authorizationGrantTypes:
      - "client_credentials"
      - "authorization_code"
   scopes:
      - name: "openid"
      - name: "email"
      - name: "profile"
      - name: "roles"
      - name: "message.read"
EOF

kubectl apply -f sso-java-clientregistration-internal.yaml

kubectl get clientregistration tanzu-java-clientregistration-internal -n default -o yaml

kubectl get authservers
sleep 5

#confirm return of access token
CLIENT_ID=$(kubectl get secret tanzu-java-clientregistration-internal -n default -o jsonpath="{.data.client-id}" | base64 -d)
CLIENT_SECRET=$(kubectl get secret tanzu-java-clientregistration-internal -n default -o jsonpath="{.data.client-secret}" | base64 -d)
ISSUER_URI=$(kubectl get secret tanzu-java-clientregistration-internal -n default -o jsonpath="{.data.issuer-uri}" | base64 -d)
curl -XPOST "$ISSUER_URI/oauth2/token?grant_type=client_credentials&scope=message.read" -u "$CLIENT_ID:$CLIENT_SECRET"

