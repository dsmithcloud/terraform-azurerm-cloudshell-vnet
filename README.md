# tf-cloudshell-vnet
Terraform Module to provision all the resources necessary to connect Cloud Shell to an existing Azure VNET

## Usage

```terraform
module "cloudshell-vnet" {
  source                       = "git::https://github.com/dsmithcloud/tf-cloudshell-vnet.git"
  region                       = "southcentralus"
  existing-vnet-name           = "vnet-core-ussc-10.0.0.0_24"
  existing-vnet-resource-group = "rg-global-core-network"
  ACI-OID                      = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  container-subnet-prefix      = ["10.0.0.96/27"]
  relay-subnet-prefix          = ["10.0.0.128/26"]
  relay-namespace-name         = "cshrelay"           #Must be globally unique
  storageaccount-name          = "storageacctname"    #Must be globally unique
  tags                         = {
    "key_1" = "value_1"
    "key_2" = "value_2" 
  }
}
```
