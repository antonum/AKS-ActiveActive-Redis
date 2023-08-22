
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  location = var.region1
  name     = var.azure_rg
}

resource "azurerm_kubernetes_cluster" "k8s1" {
  location            = var.region1
  name                = "redis-${var.region1}"
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "redis"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "agentpool"
    vm_size    = var.instance_type
    node_count = 3
  }
  
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
}

resource "azurerm_kubernetes_cluster" "k8s2" {
  location            = var.region2
  name                = "redis-${var.region2}"
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "redis"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "agentpool"
    vm_size    = var.instance_type
    node_count = 3
  }
  
  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
}