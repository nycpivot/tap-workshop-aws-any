# TAP Workshop

VMware Tanzu Application Platform (TAP) is a complete end-to-end supply chain capable of monitoring a source code repository for changes, compiling and building executable binaries packaged into OCI-conformant containers, deployed to any Kubernetes cluster running on-premises or a public cloud provider. This requires several different components with different responsibilities communicating with one another.

This repository offers application developers and operators practical examples for getting started with TAP (Tanzu Application Platform) on AWS with any Container Registry, except Elastic Container Registry (ECR). To run a workshop using ECR, refer to that [repository](https://github.com/nycpivot/tap-workshop-aws-ecr).

## Getting Started

The two scripts in the root directory can be run to bootstrap an Ubuntu Linux jumpbox in the target environment and install all prerequisites needed to run the workshop.

* [01-tanzu-operator-new.sh](01-tanzu-operator-new.sh), this script will execute an AWS *CloudFormation stack that will create an EC2 instance in the default network.
* [02-tanzu-operator-prereqs.sh](02-tanzu-operator-prereqs.sh), this script installs all the prerequisites necessary for the workshop. You will need your AWS Access Key and Secret.

If you prefer to operate the cluster on your local machine, the following prerequisites will be required.

*NOTE: The CloudFormation stack expects an existing Security Group and Key Pair.

## Prerequisites

* Docker
* AWS CLI
* kubectl
* helm, jq, etc...

Once these prerequisites have been met, the operator has the following options for the TAP installation.

## TAP Installation

### Architecture

* [Single Cluster](full-profile), all the components of TAP can be run on a single cluster, also known as Full Profile. This is the easiest and quickest setup for learning the basics of TAP.

* [Multi Cluster](multi-profile), the components are assigned to separate clusters based on their function, also known as Multi-Profile. This architecture is preferred for production environments. For example, application builds are managed separate from live application workloads.

The multi-profile architecture lends itself to scaling clusters differently according to usage. For example, application workloads on the Run cluster can scale more or less nodes depending on the usage, without the need to scale a build cluster.

For a complete reference architecture, see [TAP Reference Architecture](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap-reference-architecture/GUID-reference-designs-tap-architecture-planning.html)

### Installation Types

* [CLI](cli), relies solely on the Tanzu CLI and TAP plugins.
* [GitOps](gitops), uses mostly configuration files stored in a Git repository, and limited Tanzu CLI.

## Goals

The following is a common set of use-cases explored in this repository that most operators and developers will encounter.

* [TAP Services Toolkit](https://docs.vmware.com/en/Services-Toolkit-for-VMware-Tanzu-Application-Platform/index.html), used to make backend services, such as, databases, caches, queues, and more, easily discoverable across numerous disparate platforms and to bind the connection details to application workloads.
