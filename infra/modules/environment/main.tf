# One Setlist environment (Dev, UAT or Prod): web app, API, Key Vault and app database.
# The resource group, the GitHub deploy identity and its role assignments come from
# infra/bootstrap, so this module needs only rights on its own resource group.

data "azurerm_client_config" "current" {}

locals {
  # Globally unique names need a suffix. Deriving it from the subscription and
  # environment keeps it stable across runs without storing a random value.
  suffix = substr(sha1("${data.azurerm_client_config.current.subscription_id}-${var.environment}"), 0, 6)

  tags = {
    app         = "setlist"
    environment = var.environment
    managed_by  = "terraform"
  }

  # Vite's dev server, so the web app can call the Dev API from a laptop.
  local_origins = var.environment == "dev" ? ["http://localhost:5173"] : []
}

# --- Web app -----------------------------------------------------------------

resource "azurerm_static_web_app" "web" {
  name                = "swa-setlist-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = "Free"
  sku_size            = "Free"
  tags                = local.tags
}

# --- API ---------------------------------------------------------------------

# Flex Consumption keeps its deployment package and host state in this account.
resource "azurerm_storage_account" "functions" {
  name                            = "stsetlist${var.environment}${local.suffix}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = local.tags
}

resource "azurerm_storage_container" "deployments" {
  name                  = "deployments"
  storage_account_id    = azurerm_storage_account.functions.id
  container_access_type = "private"
}

resource "azurerm_service_plan" "api" {
  name                = "asp-setlist-${var.environment}"
  resource_group_name = var.resource_group_name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = local.tags
}

resource "azurerm_function_app_flex_consumption" "api" {
  name                = "func-setlist-${var.environment}-${local.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.api.id

  runtime_name           = "node"
  runtime_version        = "24"
  instance_memory_in_mb  = 2048
  maximum_instance_count = var.function_maximum_instance_count

  # The app reads its deployment package and host storage with its own identity,
  # so no storage key is kept in its settings.
  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.functions.primary_blob_endpoint}${azurerm_storage_container.deployments.name}"
  storage_authentication_type = "SystemAssignedIdentity"

  https_only = true
  # Deploys sign in with Entra ID (OIDC), never with publishing passwords.
  webdeploy_publish_basic_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    AzureWebJobsStorage__accountName = azurerm_storage_account.functions.name
    SETLIST_ENVIRONMENT              = var.environment
  }

  site_config {
    minimum_tls_version = "1.2"

    # Static Web Apps Free can't link its own Functions app, so the web app calls
    # the API's own hostname directly.
    cors {
      allowed_origins = concat(["https://${azurerm_static_web_app.web.default_host_name}"], local.local_origins)
    }
  }

  tags = local.tags
}

resource "azurerm_role_assignment" "api_storage" {
  scope                = azurerm_storage_account.functions.id
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = azurerm_function_app_flex_consumption.api.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# --- Secrets -----------------------------------------------------------------

# Holds the Anthropic API key. Terraform never sees its value: it is added by hand
# in UAT and Prod, and Dev uses the fake Suggestion Provider.
resource "azurerm_key_vault" "this" {
  name                       = "kv-setlist-${var.environment}-${local.suffix}"
  resource_group_name        = var.resource_group_name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.tags
}

resource "azurerm_role_assignment" "api_key_vault" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_function_app_flex_consumption.api.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# --- App database ------------------------------------------------------------

resource "azurerm_mssql_server" "this" {
  name                = "sql-setlist-${var.environment}-${local.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = "12.0"
  minimum_tls_version = "1.2"
  tags                = local.tags

  # Entra ID sign-in only, so no SQL password exists. The API signs in with its
  # managed identity once a migration creates its database user.
  azuread_administrator {
    login_username              = var.sql_admin.login_username
    object_id                   = var.sql_admin.object_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    azuread_authentication_only = true
  }
}

# 0.0.0.0 is Azure's special rule for "allow Azure services". Nothing else is let in;
# the player adds their own IP by hand when they need direct access.
resource "azurerm_mssql_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.this.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# azurerm has no setting for the free offer, so the database is created through the
# ARM API directly. The free-limit behaviour is fixed at creation: AutoPause pauses
# the database for the rest of the month instead of billing.
resource "azapi_resource" "app_database" {
  type      = "Microsoft.Sql/servers/databases@2023-08-01"
  name      = "sqldb-setlist-app"
  parent_id = azurerm_mssql_server.this.id
  location  = var.location
  tags      = local.tags

  body = {
    sku = {
      name     = "GP_S_Gen5"
      tier     = "GeneralPurpose"
      family   = "Gen5"
      capacity = 2
    }
    properties = {
      useFreeLimit                     = true
      freeLimitExhaustionBehavior      = "AutoPause"
      maxSizeBytes                     = 34359738368 # 32 GB, the free limit
      autoPauseDelay                   = 60
      minCapacity                      = 0.5
      requestedBackupStorageRedundancy = "Local"
      zoneRedundant                    = false
    }
  }
}
