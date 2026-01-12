terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "random_pet" "data_factory" {
  length    = 2
  separator = "-"
}

locals {
  data_factory_name = var.data_factory_name != null ? var.data_factory_name : "${var.data_factory_name_prefix}-${random_pet.data_factory.id}"
}

resource "azurerm_data_factory" "main" {
  name                = local.data_factory_name
  location            = coalesce(var.location, data.azurerm_resource_group.main.location)
  resource_group_name = data.azurerm_resource_group.main.name
  tags                = var.tags
}
