# tf-cloudshell-vnet
Terraform Module to provision all the resources necessary to connect Cloud Shell to an existing Azure VNET

## Supported Regions
The allowed locations are 'westus,southcentralus,eastus,northeurope,westeurope,centralindia,southeastasia,westcentralus,eastus2euap,centraluseuap'

## Usage

```terraform
module "cloudshell-vnet" {
  source                       = "git::https://github.com/dsmithcloud/tf-cloudshell-vnet.git"
  existing-vnet-name           = "vnet-core-ussc-10.0.0.0_24"
  existing-vnet-resource-group = "rg-global-core-network"
  ACI-OID                      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  container-subnet-prefix      = ["10.0.0.96/27"]
  relay-subnet-prefix          = ["10.0.0.128/26"]
  relay-namespace-name         = "cshrelay"           #Optional - Must be globally unique
  storageaccount-name          = "storageacctname"    #Optional - Must be globally unique
  tags                         =                      #Optional
  depends_on = [azurerm_resource_group.my-rg-name]    #Include if you are also creating the rg and vnet at the same time
}
```
