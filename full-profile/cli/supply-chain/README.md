# OOTB SUPPLY CHAINS

The [01-ootb-basic.sh](01-ootb-basic.sh) is the default supply chain which is run at the end of the [01-tap-full-eks-prereqs.sh](../01-tap-full-eks-prereqs.sh).

You can swap out any of the supply chains with another just by running its respective script. For example, to replace the Basic Supply Chain with Testing, just run the Testing script over top of Basic, without running the entire 01-tap-full-eks-prereqs.sh file again.
With Docker, the AWS CLI, and kubectl installed, it's time to create an EKS Cluster and ACR (Azure Container Registry), and the Tanzu CLI tools responsible for the installation. The following outline lists the sequence of steps in [01-tap-full-eks-prereqs.sh](01-tap-full-eks-prepreqs.sh). It begins by setting some environment variables, and retrieving an access token for the retrieval of packages and images from Tanzu Network.

* EKS Cluster and supporting tools and configurations.
* Install EKS CSI Driver, IAM Role and Policy.
* Download and install Tanzu CLI, Plugins, and Essentials.
* Import TAP pakages into target registry from Tanzu Network.
* Clone sample workload to deploy through pipeline when changes are committed.

The script will then call into one of three Out-Of-The-Box (OOTB) [Supply Chain](supply-chain) configurations.

* OOTB Supply Chain Basic, pushes an application workload through the supply chain to the Run cluster without any intervening steps.
* OOTB Supply Chain Testing, runs application unit testing on source code while being pushed through the supply chain to the Run cluster.
* OOTB Supply Chain Testing & Scanning, runs application unit testing on source code, followed by image scans while being pushed through the supply chain to the Run cluster.
