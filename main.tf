#================    Subnets    ================
resource "azurerm_subnet" "container-subnet" {
  name                 = var.container-subnet-name
  address_prefixes     = var.container-subnet-prefix
  resource_group_name  = var.existing-vnet-resource-group
  virtual_network_name = var.existing-vnet-name
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "delegation"
    service_delegation { name = "Microsoft.ContainerInstance/containerGroups" }
  }
}

resource "azurerm_subnet" "relay-subnet" {
  name                                           = var.relay-subnet-name
  address_prefixes                               = var.relay-subnet-prefix
  resource_group_name                            = var.existing-vnet-resource-group
  virtual_network_name                           = var.existing-vnet-name
  enforce_private_link_endpoint_network_policies = true  #true = Disable; false = Enable
  enforce_private_link_service_network_policies  = false #true = Disable; false = Enable
  depends_on = [
    azurerm_subnet.container-subnet
  ]
}

#================    Network Profile    ================
resource "azurerm_network_profile" "network-profile" {
  name                = "${var.existing-vnet-name}-profile"
  resource_group_name = var.existing-vnet-resource-group
  location            = var.region
  container_network_interface {
    name = "eth-${azurerm_subnet.container-subnet.name}"
    ip_configuration {
      name      = "ipconfig-${azurerm_subnet.container-subnet.name}"
      subnet_id = azurerm_subnet.container-subnet.id
    }
  }
  tags = var.tags
  depends_on = [
    azurerm_subnet.container-subnet
  ]
}

#================    Relay Namespace   ================
resource "azurerm_relay_namespace" "relay-namespace" {
  name                = var.relay-namespace-name # must be unique
  resource_group_name = var.existing-vnet-resource-group
  location            = var.region
  sku_name            = "Standard"
  tags                = var.tags
}

#================    Role Assignments    ================
data "azurerm_subscription" "current" {
}

data "azurerm_role_definition" "contributorRoleDefinitionId" {
  role_definition_id = "b24988ac-6180-42a0-ab88-20f7382dd24c"
  scope              = data.azurerm_subscription.current.id
}

data "azurerm_role_definition" "networkRoleDefinitionId" {
  role_definition_id = "4d97b98b-1d4f-4787-a291-c67834d212e7"
  scope              = data.azurerm_subscription.current.id
}

resource "azurerm_role_assignment" "role-assignment-network" {
  name                 = uuidv5("oid", "${var.ACI-OID}")
  scope                = azurerm_network_profile.network-profile.id
  role_definition_name = data.azurerm_role_definition.networkRoleDefinitionId.name
  principal_id         = var.ACI-OID
  depends_on = [
    azurerm_network_profile.network-profile
  ]
}

resource "azurerm_role_assignment" "role-assignment-contributor" {
  name                 = uuidv5("oid", "${var.ACI-OID}")
  scope                = azurerm_relay_namespace.relay-namespace.id
  role_definition_name = data.azurerm_role_definition.contributorRoleDefinitionId.name
  principal_id         = var.ACI-OID
  depends_on = [
    azurerm_relay_namespace.relay-namespace
  ]
}

#================    Private Endpoints    ================
resource "azurerm_private_endpoint" "private-endpoint" {
  name                = var.private-endpoint-name
  resource_group_name = var.existing-vnet-resource-group
  location            = var.region
  subnet_id           = azurerm_subnet.relay-subnet.id
  private_service_connection {
    name                           = "${data.azurerm_virtual_network.virtual-network.location}-privsvc" # Max Length 80 characters
    private_connection_resource_id = azurerm_relay_namespace.relay-namespace.id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }
  tags = var.tags
  depends_on = [
    azurerm_relay_namespace.relay-namespace,
    azurerm_subnet.relay-subnet
  ]
}

#================    Private DNS    ================
data "azurerm_virtual_network" "virtual-network" {
  resource_group_name = var.existing-vnet-resource-group
  name                = var.existing-vnet-name
}
resource "azurerm_private_dns_zone" "global-private-dns-zone" {
  name                = "privatelink.servicebus.windows.net"
  resource_group_name = var.existing-vnet-resource-group
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns-zone-link" {
  name                  = azurerm_relay_namespace.relay-namespace.name
  resource_group_name   = var.existing-vnet-resource-group
  private_dns_zone_name = "privatelink.servicebus.windows.net"
  virtual_network_id    = data.azurerm_virtual_network.virtual-network.id
  depends_on            = [azurerm_private_dns_zone.global-private-dns-zone]
}

resource "azurerm_private_dns_a_record" "ussc-dns-a-record" {
  name                = azurerm_relay_namespace.relay-namespace.name
  zone_name           = azurerm_private_dns_zone.global-private-dns-zone.name
  resource_group_name = var.existing-vnet-resource-group
  ttl                 = 3600
  records             = [cidrhost(var.relay-subnet-prefix[0], 4)]
  depends_on          = [azurerm_private_dns_zone.global-private-dns-zone]
}

#================    Storage    ================
resource "azurerm_storage_account" "storageaccount" {
  name                     = var.storageaccount-name
  resource_group_name      = var.existing-vnet-resource-group
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = 1.2

  tags = merge(var.tags, { ms-resource-usage = "azure-cloud-shell" })
}

resource "azurerm_storage_account_network_rules" "cshellstor-fwrules" {
  storage_account_id         = azurerm_storage_account.storageaccount.id
  default_action             = "Deny"
  virtual_network_subnet_ids = [azurerm_subnet.container-subnet.id]
}
