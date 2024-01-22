terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">3.0.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  tenant_databases = {
    "Tenant_A" = {
      db_max_size_gb = 2
    }
    "Tenant_B" = {
      db_max_size_gb = 2
    }
    "Tenant_C" = {
      db_max_size_gb = 2
    }
    "Tenant_D" = {
      db_max_size_gb = 2
    },
    "Tenant_E" = {
      db_max_size_gb = 2
    }
  }
  location = "East US 2"
  # Your Entra login and Object ID
  login_username = "myusername@mytenant.com"
  login_object_id = "00000000-0000-0000-0000-000000000000"
}

resource "azurerm_resource_group" "rg_mt_demo" {
  name      = "rg-mt-demo"
  location  = local.location
}

resource "azurerm_mssql_server" "sql_server_mt_demo" {
  name                           = "sql-server-mt-demo"
  location                       = local.location
  resource_group_name            = azurerm_resource_group.rg_mt_demo.name
  version                        = "12.0"
  minimum_tls_version            = "1.2"
  public_network_access_enabled  = true

  azuread_administrator {
    login_username              = local.login_username
    object_id                   = local.login_object_id
    azuread_authentication_only = true
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_mssql_database" "mgmt_db_mt_demo" {
  name         = "mgmt-db-mt-demo"
  server_id    = azurerm_mssql_server.sql_server_mt_demo.id
  max_size_gb  = 4
  sku_name     = "GP_Gen5_2"
}

resource "azurerm_mssql_elasticpool" "pool_mt_demo" {
  name                = "pool-mt-demo"
  resource_group_name = azurerm_resource_group.rg_mt_demo.name
  location            = local.location
  server_name         = azurerm_mssql_server.sql_server_mt_demo.name
  max_size_gb         = 10

  sku {
    name     = "GP_Gen5"
    capacity = 2
    tier     = "GeneralPurpose"
    family   = "Gen5"
  }

  per_database_settings {
    min_capacity = 0
    max_capacity = 2
  }
}

resource "azurerm_mssql_database" "tenant_databases_mt_demo" {
  for_each = local.tenant_databases

  name            = each.key
  server_id       = azurerm_mssql_server.sql_server_mt_demo.id
  elastic_pool_id = azurerm_mssql_elasticpool.pool_mt_demo.id
  max_size_gb     = each.value.db_max_size_gb
  sku_name        = "ElasticPool"
}

resource "azurerm_storage_account" "artifact_storage_mt_demo" {
  name                     = "artifactstoragemtdemo"
  resource_group_name      = azurerm_resource_group.rg_mt_demo.name
  location                 = local.location
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "storage_container" {
  name                  = "mt-demo-artifact"
  storage_account_name  = azurerm_storage_account.artifact_storage_mt_demo.name
}