 #!/bin/bash

## USAGE
function usage() {
    echo
    echo "Usage:"
    echo " $0 [command] [options]"
    echo " $0 --help"
    echo
    echo "Example:"
    echo " $0 install_cluster"
    echo
    echo "COMMANDS:"
    echo "   install_cluster          Install ARO4 Cluster                         "
    echo "   obtain_info              Obtain information about the ARO4 Cluster    "
    echo "   delete_cluster           Delete ARO4 cluster                          "
    echo
}

while :; do
    case $1 in
        install_cluster)
            ARG_COMMAND=install_cluster
            ;;
        obtain_info)
            ARG_COMMAND=obtain_info
            ;;
        delete_cluster)
            ARG_COMMAND=delete_cluster
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *) # Default case: If no more options then break out of the loop.
            break
    esac

    shift
done

## GLOBAL VARS
# Export the global variables for ARO
export LOCATION=eastus
export RESOURCEGROUP=aro-rg
export CLUSTER=rcarrata
export VNET_CIDR="10.0.0.0/22"
export MASTER_SUBNET_CIDR="10.0.0.0/23"
export WORKER_SUBNET_CIDR="10.0.2.0/23"


## FUNCS

# Install ARO4 Cluster
function install_cluster() {

  # Login to Azure with az cli
  echo "Login to AZ Portal"
  az login

  # Register the resource providers
  echo "Registering the resource providers"
  az provider register -n Microsoft.RedHatOpenShift --wait
  az provider register -n Microsoft.Compute --wait
  az provider register -n Microsoft.Storage --wait

  # Create resource group
  echo "Creating the Resource Groups"
  az group create --name $RESOURCEGROUP --location $LOCATION

  # Create the Virtual Network
  echo "Creating the Virtual Network"
  az network vnet create --resource-group $RESOURCEGROUP \
  --name aro-vnet --address-prefixes $VNET_CIDR

  # Add an empty subnet for the master nodes
  echo "Creating the Master Subnet"
  az network vnet subnet create \
      --resource-group $RESOURCEGROUP \
      --vnet-name aro-vnet \
      --name master-subnet \
      --address-prefixes $MASTER_SUBNET_CIDR \
      --service-endpoints Microsoft.ContainerRegistry

  # Add an empty subnet for the worker nodes
  echo "Creating the Worker Subnet"
  az network vnet subnet create \
      --resource-group $RESOURCEGROUP \
      --vnet-name aro-vnet \
      --name worker-subnet \
      --address-prefixes $WORKER_SUBNET_CIDR \
      --service-endpoints Microsoft.ContainerRegistry

  # Disable subnet private endpoint policies on the master subnet.
  echo "Disabling private endpoint policies for Master Subnet"
  az network vnet subnet update \
      --name master-subnet \
      --resource-group $RESOURCEGROUP \
      --vnet-name aro-vnet \
      --disable-private-link-service-network-policies true

  # Small Error Control
  if [ ! -f pull-secret.txt ]; then
          echo "Pull Secret not found! Please download it from https://cloud.redhat.com/openshift/install/azure/aro-provisioned"
  fi

  # Create the ARO cluster
  echo "Creating ARO Cluster... Please wait 40mins"
  az aro create --resource-group $RESOURCEGROUP \
      --name $CLUSTER --vnet aro-vnet  \
      --master-subnet master-subnet \
      --worker-subnet worker-subnet \
      --pull-secret @pull-secret.txt

}

function obtain_info() {

  # List Credentials
  echo "List credentials for ARO Cluster"
  az aro list-credentials \
      --name $CLUSTER \
      --resource-group $RESOURCEGROUP
  echo ""

  # Show Console
  echo "List console for ARO cluster"
  az aro show \
      --name $CLUSTER \
      --resource-group $RESOURCEGROUP \
      --query "consoleProfile.url" -o tsv
  echo ""

  # Show API
  apiServer=$(az aro show -g $RESOURCEGROUP -n $CLUSTER --query apiserverProfile.url -o tsv)
  echo "This is the API for your cluster: $apiServer"
  echo ""

}

function delete_cluster() {

  az aro delete --resource-group $RESOURCEGROUP --name $CLUSTER

}


## MAIN
case "$ARG_COMMAND" in
    install_cluster)
        echo "Installing ARO4 Cluster"
        install_cluster
        echo
        echo "Completed successfully!"
        ;;

    obtain_info)
        echo "Obtaining Info..."
        obtain_info
        echo
        echo "Completed successfully!"
        ;;

    delete_cluster)
        echo "Deleting ARO4 Cluster"
        delete_cluster
        echo
        echo "Completed successfully!"
        ;;
    *)
        echo "Invalid command specified: '$ARG_COMMAND'"
        usage
        ;;
esac