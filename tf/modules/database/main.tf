terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "awx-initial-build" {
  name     = "awx"
  location = "UK South"
}

resource "azurerm_virtual_network" "awx-initial-build" {
  name                = "awx_local"
  resource_group_name = azurerm_resource_group.awx-initial-build.name
  location            = azurerm_resource_group.awx-initial-build.location
  address_space       = ["172.21.0.0/16"]
}

resource "azurerm_subnet" "awx-database-build-endpoint" {
  name                                           = "awx_local_db"
  resource_group_name                            = azurerm_resource_group.awx-initial-build.name
  virtual_network_name                           = azurerm_virtual_network.awx-initial-build.name
  address_prefixes                               = ["172.21.252.0/24"]
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_postgresql_server" "awx-database-build" {
  name                = "awx-local-postgres"
  location            = azurerm_resource_group.awx-initial-build.location
  resource_group_name = azurerm_resource_group.awx-initial-build.name

  sku_name = "GP_Gen5_2"

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = false

  administrator_login           = "awxadmin"
  administrator_login_password  = "awxPassw0rd"
  public_network_access_enabled = true
  version                       = "11"
  ssl_enforcement_enabled       = false
}

resource "azurerm_postgresql_database" "awx-database-build" {
  name                = "netbox"
  resource_group_name = azurerm_resource_group.awx-initial-build.name
  server_name         = azurerm_postgresql_server.awx-database-build.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_postgresql_firewall_rule" "awx-database-build" {
  name                = "office"
  resource_group_name = azurerm_resource_group.awx-initial-build.name
  server_name         = azurerm_postgresql_server.awx-database-build.name
  start_ip_address    = "87.254.91.243"
  end_ip_address      = "87.254.91.243"
}

resource "azurerm_private_endpoint" "awx-database-build" {
  name                = "awx_local_db_end"
  location            = azurerm_resource_group.awx-initial-build.location
  resource_group_name = azurerm_resource_group.awx-initial-build.name
  subnet_id           = azurerm_subnet.awx-database-build-endpoint.id

  private_service_connection {
    name                           = "awx_local_link02_conn"
    private_connection_resource_id = azurerm_postgresql_server.awx-database-build.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }
}