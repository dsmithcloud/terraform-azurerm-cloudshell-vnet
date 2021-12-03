output "container-subnet-id" {
  value = azurerm_subnet.container-subnet.subnet_id
}

output "relay-subnet-id" {
  value = azurerm_subnet.relay-subnet.subnet_id
}
