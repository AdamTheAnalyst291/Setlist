# Plan-only tests with mocked providers: no Azure sign-in, nothing created.
# They pin the choices that keep an environment on Azure's free services.
# Run with: terraform -chdir=infra/modules/environment test

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000001"
      tenant_id       = "00000000-0000-0000-0000-000000000002"
      object_id       = "00000000-0000-0000-0000-000000000003"
    }
  }

  mock_resource "azurerm_storage_account" {
    defaults = {
      primary_blob_endpoint = "https://stsetlistdevabc123.blob.core.windows.net/"
    }
  }
}

mock_provider "azapi" {}

variables {
  environment         = "dev"
  resource_group_name = "rg-setlist-dev"
  location            = "eastus2"
  sql_admin = {
    login_username = "setlist-github-dev"
    object_id      = "00000000-0000-0000-0000-000000000003"
  }
}

run "web_app_is_on_the_free_plan" {
  command = plan

  assert {
    condition     = azurerm_static_web_app.web.sku_tier == "Free" && azurerm_static_web_app.web.sku_size == "Free"
    error_message = "Static Web Apps must use the Free plan."
  }
}

run "api_is_a_flex_consumption_node_24_app_with_a_managed_identity" {
  command = plan

  assert {
    condition     = azurerm_service_plan.api.sku_name == "FC1" && azurerm_service_plan.api.os_type == "Linux"
    error_message = "The API must run on the Linux Flex Consumption plan (FC1)."
  }

  assert {
    condition     = azurerm_function_app_flex_consumption.api.runtime_name == "node" && azurerm_function_app_flex_consumption.api.runtime_version == "24"
    error_message = "The API must run on Node 24."
  }

  assert {
    condition     = azurerm_function_app_flex_consumption.api.identity[0].type == "SystemAssigned"
    error_message = "The API needs a system-assigned managed identity."
  }

  assert {
    condition     = azurerm_function_app_flex_consumption.api.storage_authentication_type == "SystemAssignedIdentity"
    error_message = "The API must reach its storage with its managed identity, not a key."
  }

  assert {
    condition     = length(azurerm_function_app_flex_consumption.api.always_ready) == 0
    error_message = "Always-ready instances are billed outside the free grant."
  }

  assert {
    condition     = contains(azapi_resource_action.api_cors.body.properties.cors.allowedOrigins, "http://localhost:5173")
    error_message = "Dev's API must accept calls from the local Vite server."
  }
}

run "api_can_read_key_vault_secrets" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.api_key_vault.role_definition_name == "Key Vault Secrets User"
    error_message = "The API's identity must be able to read Key Vault secrets."
  }

  assert {
    condition     = azurerm_key_vault.this.rbac_authorization_enabled
    error_message = "Key Vault access must use Azure RBAC."
  }
}

run "app_database_uses_the_free_offer_and_pauses_instead_of_billing" {
  command = plan

  assert {
    condition     = azapi_resource.app_database.body.properties.useFreeLimit == true
    error_message = "The app database must use the Azure SQL free offer."
  }

  assert {
    condition     = azapi_resource.app_database.body.properties.freeLimitExhaustionBehavior == "AutoPause"
    error_message = "The app database must pause, not bill, when the free allowance runs out."
  }
}

run "sql_server_accepts_entra_sign_in_and_azure_services_only" {
  command = plan

  assert {
    condition     = azurerm_mssql_server.this.azuread_administrator[0].azuread_authentication_only
    error_message = "The SQL server must accept Microsoft Entra sign-in only."
  }

  assert {
    condition     = azurerm_mssql_firewall_rule.azure_services.start_ip_address == "0.0.0.0" && azurerm_mssql_firewall_rule.azure_services.end_ip_address == "0.0.0.0"
    error_message = "The only firewall rule must be Azure's allow-Azure-services rule."
  }
}

run "non_dev_api_does_not_accept_localhost" {
  command = plan

  variables {
    environment = "prod"
  }

  assert {
    condition     = !contains(azapi_resource_action.api_cors.body.properties.cors.allowedOrigins, "http://localhost:5173")
    error_message = "Only Dev may accept calls from localhost."
  }
}

run "rejects_unknown_environment_names" {
  command = plan

  variables {
    environment = "staging"
  }

  expect_failures = [var.environment]
}
