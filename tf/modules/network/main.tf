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

resource "azurerm_subnet" "awx-initial-build-service" {
  name                                          = "awx_local_sub01"
  resource_group_name                           = azurerm_resource_group.awx-initial-build.name
  virtual_network_name                          = azurerm_virtual_network.awx-initial-build.name
  address_prefixes                              = ["172.21.180.0/24"]
  enforce_private_link_service_network_policies = true
}

resource "azurerm_subnet" "awx-initial-build-endpoint" {
  name                                           = "awx_local_sub02"
  resource_group_name                            = azurerm_resource_group.awx-initial-build.name
  virtual_network_name                           = azurerm_virtual_network.awx-initial-build.name
  address_prefixes                               = ["172.21.183.0/24"]
  enforce_private_link_endpoint_network_policies = true
}

resource "azurerm_public_ip" "awx-initial-build" {
  name                = "awx_pip01"
  sku                 = "Standard"
  location            = azurerm_resource_group.awx-initial-build.location
  resource_group_name = azurerm_resource_group.awx-initial-build.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "awx-initial-build" {
  name                = "awx_local_lb01"
  sku                 = "Standard"
  location            = azurerm_resource_group.awx-initial-build.location
  resource_group_name = azurerm_resource_group.awx-initial-build.name

  frontend_ip_configuration {
    name                 = azurerm_public_ip.awx-initial-build.name
    public_ip_address_id = azurerm_public_ip.awx-initial-build.id
  }
}

resource "azurerm_private_link_service" "awx-initial-build" {
  name                = "awx_local_link01"
  location            = azurerm_resource_group.awx-initial-build.location
  resource_group_name = azurerm_resource_group.awx-initial-build.name
  load_balancer_frontend_ip_configuration_ids = [
    azurerm_lb.awx-initial-build.frontend_ip_configuration.0.id,
  ]

  nat_ip_configuration {
    name                       = "awx_local_lb01_nat01"
    private_ip_address         = "172.21.180.4"
    private_ip_address_version = "IPv4"
    primary                    = true
    subnet_id                  = azurerm_subnet.awx-initial-build-service.id
  }

  nat_ip_configuration {
    name                       = "awx_local_lb01_nat02"
    private_ip_address         = "172.21.180.5"
    private_ip_address_version = "IPv4"
    primary                    = false
    subnet_id                  = azurerm_subnet.awx-initial-build-service.id
  }
}

resource "azurerm_private_endpoint" "awx-initial-build" {
  name                = "awx_local_sub02_end"
  location            = azurerm_resource_group.awx-initial-build.location
  resource_group_name = azurerm_resource_group.awx-initial-build.name
  subnet_id           = azurerm_subnet.awx-initial-build-endpoint.id

  private_service_connection {
    name                           = "awx_local_link01_conn"
    private_connection_resource_id = azurerm_private_link_service.awx-initial-build.id
    is_manual_connection           = false
  }
}
