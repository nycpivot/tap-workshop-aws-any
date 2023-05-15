cluster_name=tap-run

kubectl config use-context $cluster_name

rm sso-python-clientregistration-internal.yaml
cat <<EOF | tee sso-python-clientregistration-internal.yaml
apiVersion: sso.apps.tanzu.vmware.com/v1alpha1
kind: ClientRegistration
metadata:
   name: tanzu-python-clientregistration-internal
   namespace: default
spec:
   authServerSelector:
      matchLabels:
         name: tap-authserver-internal
         env: tutorial
   redirectURIs:
      - "http://tanzu-python-sso-app.default.run.tap.nycpivot.com/oauth2/callback"
   requireUserConsent: false
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

kubectl apply -f sso-python-clientregistration-internal.yaml

kubectl get clientregistration tanzu-python-clientregistration-internal -n default -o yaml

kubectl get authservers
sleep 5

#confirm return of access token
CLIENT_ID=$(kubectl get secret tanzu-python-clientregistration-internal -n default -o jsonpath="{.data.client-id}" | base64 -d)
CLIENT_SECRET=$(kubectl get secret tanzu-python-clientregistration-internal -n default -o jsonpath="{.data.client-secret}" | base64 -d)
ISSUER_URI=$(kubectl get secret tanzu-python-clientregistration-internal -n default -o jsonpath="{.data.issuer-uri}" | base64 -d)
curl -XPOST "$ISSUER_URI/oauth2/token?grant_type=client_credentials&scope=message.read" -u "$CLIENT_ID:$CLIENT_SECRET"


rm sso-python-app.yaml
cat <<EOF | tee sso-python-app.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tanzu-python-sso-app
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      name: tanzu-python-app-sso
  template:
    metadata:
      labels:
        name: tanzu-python-app-sso
    spec:
      containers:
        - image: bitnami/oauth2-proxy:7.3.0
          name: proxy
          ports:
            - containerPort: 4180
              name: proxy-port
              protocol: TCP
          env:
            - name: ISSUER_URI
              valueFrom:
                secretKeyRef:
                  name: tanzu-python-clientregistration-internal
                  key: issuer-uri
            - name: CLIENT_ID
              valueFrom:
                secretKeyRef:
                  name: tanzu-python-clientregistration-internal
                  key: client-id
            - name: CLIENT_SECRET
              valueFrom:
                secretKeyRef:
                  name: tanzu-python-clientregistration-internal
                  key: client-secret
          command: [ "oauth2-proxy" ]
          args:
            - --oidc-issuer-url=\$(ISSUER_URI)
            - --client-id=\$(CLIENT_ID)
            - --insecure-oidc-skip-issuer-verification=true
            - --client-secret=\$(CLIENT_SECRET)
            - --cookie-secret=0000000000000000
            - --cookie-secure=false
            - --http-address=http://:4180
            - --provider=oidc
            - --scope=openid email profile roles
            - --email-domain=*
            - --insecure-oidc-allow-unverified-email=true
            - --oidc-groups-claim=roles
            - --upstream=http://127.0.0.1:8000
            - --redirect-url=http://tanzu-python-sso-app.default.run.tap.nycpivot.com/oauth2/callback
            - --skip-provider-button=true
            - --pass-authorization-header=true
            - --prefer-email-to-user=true
        - image: python:3.9
          name: application
          resources:
            limits:
              cpu: 100m
              memory: 100Mi
          command: [ "python" ]
          args:
            - -c
            - |
              from http.server import HTTPServer, BaseHTTPRequestHandler
              import base64
              import json

              class Handler(BaseHTTPRequestHandler):
                  def do_GET(self):
                      if self.path == "/token":
                          self.token()
                          return
                      else:
                          self.greet()
                          return

                  def greet(self):
                      username = self.headers.get("x-forwarded-user")
                      self.send_response(200)
                      self.send_header("Content-type", "text/html")
                      self.end_headers()
                      page = f"""
                      <h1>It Works!</h1>
                      <p>You are logged in as <b>{username}</b></p>
                      """
                      self.wfile.write(page.encode("utf-8"))

                  def token(self):
                      token = self.headers.get("Authorization").split("Bearer ")[-1]
                      payload = token.split(".")[1]
                      decoded = base64.b64decode(bytes(payload, "utf-8") + b'==').decode("utf-8")
                      self.send_response(200)
                      self.send_header("Content-type", "application/json")
                      self.end_headers()
                      self.wfile.write(decoded.encode("utf-8"))

              server_address = ('', 8000)
              httpd = HTTPServer(server_address, Handler)
              httpd.serve_forever()
---
apiVersion: v1
kind: Service
metadata:
  name: tanzu-python-sso-app
  namespace: default
spec:
  ports:
    - port: 80
      targetPort: 4180
  selector:
    name: tanzu-python-sso-app
---
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: tanzu-python-sso-app
  namespace: default
spec:
  virtualhost:
    fqdn: tanzu-python-sso-app.default.run.tap.nycpivot.com
  routes:
    - conditions:
        - prefix: /
      services:
        - name: tanzu-python-sso-app
          port: 80
EOF

kubectl apply -f sso-python-app.yaml

kubectl get httpproxy
