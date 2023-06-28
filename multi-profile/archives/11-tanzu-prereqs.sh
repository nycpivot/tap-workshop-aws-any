#!/bin/bash
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-install-tanzu-cli.html
#https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-aws-install-intro.html
#https://docs.vmware.com/en/Cluster-Essentials-for-VMware-Tanzu/1.3/cluster-essentials/GUID-deploy.html

pivnet_user=mjames@pivotal.io

kubectl config get-contexts

read -p "Select context: " kube_context

kubectl config use-context $kube_context

#CREDS
pivnet_pass=$(az keyvault secret show --name pivnet-registry-secret --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
refresh_token=$(az keyvault secret show --name pivnet-api-refresh-token --subscription nycpivot --vault-name tanzuvault --query value --output tsv)
token=$(curl -X POST https://network.pivotal.io/api/v2/authentication/access_tokens -d '{"refresh_token":"'${refresh_token}'"}')
access_token=$(echo ${token} | jq -r .access_token)

curl -i -H "Accept: application/json" -H "Content-Type: application/json" -H "Authorization: Bearer ${access_token}" -X GET https://network.pivotal.io/api/v2/authentication


#INSTALL TANZU FRAMEWORK BUNDLE
rm -rf $HOME/tanzu
mkdir $HOME/tanzu

cli_filename=tanzu-framework-linux-amd64-v0.25.4.1.tar

rm $HOME/tanzu/${cli_filename}
wget https://network.tanzu.vmware.com/api/v2/products/tanzu-application-platform/releases/1239018/product_files/1404618/download --header="Authorization: Bearer ${access_token}" -O $HOME/tanzu/${cli_filename}
tar -xvf $HOME/tanzu/${cli_filename} -C $HOME/tanzu

export TANZU_CLI_NO_INIT=true
export VERSION=v0.25.4
cd tanzu

sudo install cli/core/$VERSION/tanzu-core-linux_amd64 /usr/local/bin/tanzu

tanzu version
sleep 5

tanzu plugin install --local cli all
tanzu plugin list

cd $HOME

#CLUSTER ESSENTIALS
rm -rf $HOME/tanzu-cluster-essentials
mkdir $HOME/tanzu-cluster-essentials

essentials_filename=tanzu-cluster-essentials-linux-amd64-1.4.0.tgz

rm $HOME/tanzu-cluster-essentials/${essentials_filename}
wget https://network.tanzu.vmware.com/api/v2/products/tanzu-cluster-essentials/releases/1238179/product_files/1407185/download --header="Authorization: Bearer ${access_token}" -O $HOME/tanzu-cluster-essentials/${essentials_filename}
tar -xvf $HOME/tanzu-cluster-essentials/${essentials_filename} -C $HOME/tanzu-cluster-essentials

export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:5fd527dda8af0e4c25c427e5659559a2ff9b283f6655a335ae08357ff63b8e7f
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
export INSTALL_REGISTRY_USERNAME=$pivnet_user
export INSTALL_REGISTRY_PASSWORD=$pivnet_pass
cd $HOME/tanzu-cluster-essentials

./install.sh --yes

sudo cp $HOME/tanzu-cluster-essentials/kapp /usr/local/bin/kapp
sudo cp $HOME/tanzu-cluster-essentials/imgpkg /usr/local/bin/imgpkg

cd $HOME

docker login registry.tanzu.vmware.com -u $pivnet_user -p $pivnet_pass
