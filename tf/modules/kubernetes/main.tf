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

resource "azurerm_public_ip" "awx-cluster-build" {
  name                = "awx_pip02"
  sku                 = "Standard"
  location            = azurerm_resource_group.awx-initial-build.location
  resource_group_name = azurerm_resource_group.awx-initial-build.name
  allocation_method   = "Static"
}

resource "azurerm_kubernetes_cluster" "awx-cluster-build" {
  name                = "awx_containers"
  location            = azurerm_resource_group.awx-initial-build.location
  resource_group_name = azurerm_resource_group.awx-initial-build.name
  dns_prefix          = "awx-local"
  sku_tier            = "Free"
  kubernetes_version  = "1.22.4"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                 = "default"
    vm_size              = "Standard_D4as_v4"
    max_pods             = 110
    orchestrator_version = "1.22.4"
    os_disk_size_gb      = 128
    os_disk_type         = "Managed"
    os_sku               = "Ubuntu"
    vnet_subnet_id       = "/subscriptions/28db1ff3-c829-44c1-b959-1306ae13b36c/resourceGroups/awx/providers/Microsoft.Network/virtualNetworks/awx_local/subnets/awx_local_sub01"
    node_count           = 1
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"

    service_cidr       = "172.21.181.0/24"
    dns_service_ip     = "172.21.181.11"
    docker_bridge_cidr = "172.17.0.1/16"

    outbound_type = "loadBalancer"
    load_balancer_profile {
      outbound_ip_address_ids = ["/subscriptions/28db1ff3-c829-44c1-b959-1306ae13b36c/resourceGroups/awx/providers/Microsoft.Network/publicIPAddresses/awx_pip02"]
    }
  }
}
