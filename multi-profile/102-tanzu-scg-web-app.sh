tanzu apps workload create tanzu-scg-web-app --git-repo https://github.com/nycpivot/tanzu-scg-web-app --git-branch main --type web --label app.kubernetes.io/part-of=tanzu-scg-web-app --yes --annotation autoscaling.knative.dev/min-scale=1

#tanzu apps workload create tap-steeltoe-web-app --type web --git-repo https://github.com/nycpivot/tap-steeltoe-web-app --git-branch main --annotation autoscaling.knative.dev/min-scale=1 --yes --label app.kubernetes.io/part-of=tap-steeltoe-web-app
