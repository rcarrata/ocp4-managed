# ARO 4 Installation

The Microsoft Azure Red Hat OpenShift service enables you to deploy fully managed OpenShift clusters.

Azure Red Hat OpenShift is jointly engineered, operated, and supported by Red Hat and Microsoft to provide an integrated support experience. There are no virtual machines to operate, and no patching is required. Master, infrastructure, and application nodes are patched, updated, and monitored on your behalf by Red Hat and Microsoft. Your Azure Red Hat OpenShift clusters are deployed into your Azure subscription and are included on your Azure bill.

When you deploy Azure Red Hat on OpenShift 4, your entire cluster is contained within a virtual network. Within this virtual network, your master nodes and workers nodes each live in their own subnet. Each subnet uses an internal load balancer and a public load balancer.

This is the official diagram (available in ARO4 Microsoft page) about Azure Red Hat OpenShift 4:

<img align="center" width="750" src="../assets/aro4-networking-diagram.png">

* For more details about the networking and the resources deployed and managed by ARO4, please check the [ARO Diagram Details - Official Docs](https://docs.microsoft.com/en-us/azure/openshift/concepts-networking#networking-components)

## Prerequisites

* Follow the [Configuring Azure Account prerequisites](https://docs.openshift.com/container-platform/latest/installing/installing_azure/installing-azure-account.html) to define and assign proper RBAC permissions and increase limits to your Azure account.

## Configuration of Azure Infrastructure Prerequisites for the ARO installation

* Define the basic parameters for the ARO4 installation:

```sh
export LOCATION=eastus
export RESOURCEGROUP=aro-rg
export CLUSTER=rcarrata
export VNET_CIDR="10.0.0.0/22"
export MASTER_SUBNET_CIDR="10.0.0.0/23"
export WORKER_SUBNET_CIDR="10.0.2.0/23"
```

* Login to Azure with az cli

```sh
az login
```

NOTE: you need to authenticate with your credentials in the Azure Portal when the login pops up.

* Register the resource providers

```sh
az provider register -n Microsoft.RedHatOpenShift --wait
az provider register -n Microsoft.Compute --wait
az provider register -n Microsoft.Storage --wait
```

* Create resource group

```sh
az group create --name $RESOURCEGROUP --location $LOCATION
```

* Create the Virtual Network

```sh
az network vnet create --resource-group $RESOURCEGROUP \
  --name aro-vnet --address-prefixes $VNET_CIDR
```

* Add an empty subnet for the master nodes

```sh
az network vnet subnet create \
    --resource-group $RESOURCEGROUP \
    --vnet-name aro-vnet \
    --name master-subnet \
    --address-prefixes $MASTER_SUBNET_CIDR \
    --service-endpoints Microsoft.ContainerRegistry
```

* Add an empty subnet for the worker nodes

```sh
az network vnet subnet create \
    --resource-group $RESOURCEGROUP \
    --vnet-name aro-vnet \
    --name worker-subnet \
    --address-prefixes $WORKER_SUBNET_CIDR \
    --service-endpoints Microsoft.ContainerRegistry
```

* Disable subnet private endpoint policies on the master subnet.

```sh
az network vnet subnet update \
    --name master-subnet \
    --resource-group $RESOURCEGROUP \
    --vnet-name aro-vnet \
    --disable-private-link-service-network-policies true
```

## Install ARO4

* Create the ARO cluster with azure cli

```sh  
  echo "Creating ARO Cluster... Please wait 40mins"
az aro create --resource-group $RESOURCEGROUP \
    --name $CLUSTER --vnet aro-vnet  \
    --master-subnet master-subnet \
    --worker-subnet worker-subnet \
    --pull-secret @pull-secret.txt
```

NOTE: a valid pull-secret it's needed for the installation. Please go to your [Cloud OpenShift Portal](cloud.redhat.com/openshift/) and get your pull-secret token.

* Then the az aro cli will provision a ARO object in the Azure Portal:

<img align="center" width="750" src="../assets/aro4_1.png">

* Automatically, an additional Azure Resource Group it's created with the Azure objects for the installation, managed by the ARO SREs from RH and MSFT:

<img align="center" width="750" src="../assets/aro4_2.png">

* Inside of this Resource Group we the resources generated that are needed for provision and configure the ARO4 cluster:

<img align="center" width="750" src="../assets/aro4_3.png">


## Get access to the API and Console

* After 40 minutes approx. we will have the ARO4 cluster ready with the Console and the API ready to be used:

<img align="center" width="750" src="../assets/aro4_4.png">

* For get access into the cluster, list Credentials for your cluster:

```sh
echo "List credentials for ARO Cluster"
az aro list-credentials \
    --name $CLUSTER \
    --resource-group $RESOURCEGROUP
echo ""
```

* To show the ARO4 Console:

```sh
echo "List console for ARO cluster"
az aro show \
    --name $CLUSTER \
    --resource-group $RESOURCEGROUP \
    --query "consoleProfile.url" -o tsv
```

* Check the ARO4 API:

```sh
apiServer=$(az aro show -g $RESOURCEGROUP -n $CLUSTER --query apiserverProfile.url -o tsv)
echo "This is the API for your cluster: $apiServer"
```

## Automated installation of ARO4

If you want to install all the Azure Infrastructure resource prerequisites and the ARO4 cluster in a simple way, we generated a script for automate the whole process described before.

* Get the ARO4 install script:

```sh
wget https://raw.githubusercontent.com/rcarrata/ocp4-managed/main/ARO/aro4_quick_install.sh
chmod u+x aro4_quick_install.sh
```

* Tweak the parameters inside of the cluster to adjust to your region, cluster_name, and network cidrs, among others:

```sh
export LOCATION=eastus
export RESOURCEGROUP=example-rg
export CLUSTER=example
export VNET_CIDR="10.0.0.0/22"
export MASTER_SUBNET_CIDR="10.0.0.0/23"
export WORKER_SUBNET_CIDR="10.0.2.0/23"
```

* Install the prerequisites and the ARO4 cluster

```sh
./aro4_quick_install.sh install_cluster
```

* Retrieve the credentials, console and api details:

```sh
./aro4_quick_install.sh obtain_info
```
