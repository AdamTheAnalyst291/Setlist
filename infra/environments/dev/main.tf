# Dev. GitHub Actions plans this on pull requests and applies it on merge to main,
# signed in as the Dev deploy identity that infra/bootstrap creates.

terraform {
  required_version = ">= 1.17.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.14"
    }
  }

  # Partial configuration: the workflow passes the storage account with -backend-config,
  # from the TF_STATE_* repository variables. State is read with Entra ID, not a key.
  backend "azurerm" {
    container_name   = "tfstate-dev"
    key              = "dev.tfstate"
    use_azuread_auth = true
  }
}

# Credentials come from ARM_* environment variables (OIDC in GitHub Actions).
provider "azurerm" {
  features {
    key_vault {
      # Purging needs a subscription-wide permission the deploy identity doesn't have.
      # A deleted vault stays soft-deleted for 7 days, then Azure purges it.
      purge_soft_delete_on_destroy = false
    }
  }

  # The deploy identity can't register providers at subscription scope;
  # infra/bootstrap registers the ones Setlist needs.
  resource_provider_registrations = "none"
  storage_use_azuread             = true
}

provider "azapi" {}

variable "deploy_identity_object_id" {
  description = "Object ID of the Dev deploy identity's service principal (GitHub variable AZURE_PRINCIPAL_ID). It administers the SQL server so the pipeline can run migrations."
  type        = string
}

module "environment" {
  source = "../../modules/environment"

  environment         = "dev"
  resource_group_name = "rg-setlist-dev"
  location            = "centralus"

  sql_admin = {
    login_username = "setlist-github-dev"
    object_id      = var.deploy_identity_object_id
  }
}

output "web_url" {
  value = module.environment.web_url
}

output "api_url" {
  value = module.environment.api_url
}

output "static_web_app_name" {
  value = module.environment.static_web_app_name
}

output "function_app_name" {
  value = module.environment.function_app_name
}

output "function_app_principal_id" {
  value = module.environment.function_app_principal_id
}

output "key_vault_name" {
  value = module.environment.key_vault_name
}

output "sql_server_fqdn" {
  value = module.environment.sql_server_fqdn
}

output "app_database_name" {
  value = module.environment.app_database_name
}
