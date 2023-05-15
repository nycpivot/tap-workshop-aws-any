# FULL PROFILE

A full profile will install all TAP components on a single cluster. Run [01-tap-full-eks.sh](01-tap-full-eks.sh) to install the following components.

## 1. Capture Pivnet Secrets

The first stage collects all the secrets for pulling images from both Tanzu network and registry TAP will use for building code and storing application images. In this workshop, AWS Secrets Manager is used for storage and AWS CLI for retrieval during installation and secrets creation in cluster.

## 2. Create AWS Resources with CloudFormation template (EKS, VPC)

The CloudFormation template creates the EKS Cluster with 5 EC2 instances hosted in two subnets in a new VPC.

## 3. Install CSI Driver on EKS cluster

AWS requires that all K8s clusters using version 1.23 or higher must manually configure storage by applying the plugins. This section in the script automates this whole process.

## 4. Create Elasic Container Registries (ECR)

Creates two registries. The first, tap-images, hosts all TAP images required for the platform to run, and the second, tap-build-service, hosts the images for compiling source code into binaries and packaging it into containers.

## 5. Setup IAM RBAC roles and policies

This section configures the roles and policies that will be attached to the cluster so it will have the necessary permissions to push and pull images to the container registry.

## 6. Install Tanzu CLI and Cluster Essentials

Installs the Tanzu CLI, its plugins, and Carvel tools.

## 7. Import TAP images into ECR

The TAP images are exported from Tanzu Network and imported into the container registry.

## 8. Install Full TAP Profile

Builds the configuration and installs TAP. The tap-values file is created and applied to the cluster.

## 9. Setup Developer Namespace

Defines the namespace(s) for running workloads and secrets for pulling images from the container registry.

## 10. Configure DNS with system ingress

This section retrieves the address of the ELB to get the corresponding IP address, which is used to update the A record of the first zone retrieved.


## TAP GUI

A URL will be output to open tap-gui in the browser.


## SERVICES TOOLKIT


