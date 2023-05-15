cluster_name=tap-profile-run
VERSION=0.1.1

kubectl config use-context $cluster_name

rm api-auto-registration-values.yaml
cat <<EOF | tee api-auto-registration-values.yaml
tap_gui_url: http://tap-gui.view.tap.nycpivot.com/
cluster_name: ${cluster_name}
EOF

tanzu package installed update api-auto-registration \
    --package-name apis.apps.tanzu.vmware.com \
    --namespace tap-install \
    --version $VERSION \
    --values-file api-auto-registration-values.yaml


