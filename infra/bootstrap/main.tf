# One-time setup, applied by hand by the subscription owner (see infra/README.md).
# It creates what the environment roots can't create for themselves:
#   - the resource providers Setlist uses, registered on the subscription
#   - a small storage account holding Terraform state, one container per environment
#   - per environment: a resource group, and a GitHub deploy identity that trusts only
#     this repository's GitHub Environment of the same name, with rights on that group
#     and on that environment's state container only
#   - the subscription's monthly budget alert
# Add "uat" and "prod" to var.environments to set those up the same way.

terraform {
  required_version = ">= 1.17.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
  }

  # State stays local (terraform.tfstate, git-ignored). It is small and can be
  # rebuilt with terraform import if lost.
}

provider "azurerm" {
  features {}

  # Pinned explicitly so this never runs against whichever subscription the Azure CLI
  # happens to have selected.
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id

  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.Consumption",
    "Microsoft.KeyVault",
    "Microsoft.ManagedIdentity",
    "Microsoft.Sql",
    "Microsoft.Storage",
    "Microsoft.Web",
  ]

  storage_use_azuread = true
}

provider "azuread" {
  tenant_id = var.tenant_id
}

locals {
  suffix = substr(sha1(var.subscription_id), 0, 6)
  tags = {
    app        = "setlist"
    managed_by = "terraform-bootstrap"
  }

  # Roles the deploy identities may hand out inside their own resource group, to the
  # API's managed identity. Nothing else, so a deploy identity can't make itself Owner.
  delegable_role_ids = [
    "b7e6dc6d-f1e8-4753-8033-0f276bb0955b", # Storage Blob Data Owner
    "4633458b-17de-408a-b874-0445c86b69e6", # Key Vault Secrets User
  ]
  delegable_roles = join(", ", local.delegable_role_ids)
}

# --- Terraform state -----------------------------------------------------------

resource "azurerm_resource_group" "state" {
  name     = "rg-setlist-tfstate"
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "state" {
  name                            = "stsetlisttf${local.suffix}"
  resource_group_name             = azurerm_resource_group.state.name
  location                        = azurerm_resource_group.state.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  # Entra ID only: state is read with role assignments, never an account key.
  shared_access_key_enabled = false
  tags                      = local.tags

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }
}

resource "azurerm_storage_container" "state" {
  for_each = var.environments

  name                  = "tfstate-${each.key}"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"
}

# --- Per environment -----------------------------------------------------------

resource "azurerm_resource_group" "environment" {
  for_each = var.environments

  name     = "rg-setlist-${each.key}"
  location = var.location
  tags     = merge(local.tags, { environment = each.key })
}

resource "azuread_application" "deploy" {
  for_each = var.environments

  display_name = "setlist-github-${each.key}"
}

resource "azuread_service_principal" "deploy" {
  for_each = var.environments

  client_id = azuread_application.deploy[each.key].client_id
}

# The only way to sign in as this identity: a GitHub Actions job in this repository
# that runs in the GitHub Environment of the same name. No client secret exists.
resource "azuread_application_federated_identity_credential" "github_environment" {
  for_each = var.environments

  application_id = azuread_application.deploy[each.key].id
  display_name   = "github-${replace(var.github_repository, "/", "-")}-${each.key}"
  description    = "GitHub Actions in ${var.github_repository}, environment ${each.key}"
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "${var.github_oidc_subject_prefix}:environment:${each.key}"
  audiences      = ["api://AzureADTokenExchange"]
}

resource "azurerm_role_assignment" "deploy_contributor" {
  for_each = var.environments

  scope                = azurerm_resource_group.environment[each.key].id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.deploy[each.key].object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "deploy_role_assignments" {
  for_each = var.environments

  scope                = azurerm_resource_group.environment[each.key].id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azuread_service_principal.deploy[each.key].object_id
  principal_type       = "ServicePrincipal"
  description          = "Lets Terraform grant the API's managed identity its storage and Key Vault roles, and nothing else."

  condition_version = "2.0"
  condition         = <<-EOT
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.delegable_roles}}
     )
    )
    AND
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
     )
     OR
     (
      @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.delegable_roles}}
     )
    )
  EOT
}

resource "azurerm_role_assignment" "deploy_state" {
  for_each = var.environments

  scope                = azurerm_storage_container.state[each.key].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.deploy[each.key].object_id
  principal_type       = "ServicePrincipal"
}

# --- Budget --------------------------------------------------------------------

resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "setlist-monthly"
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = var.budget_amount
  time_grain      = "Monthly"

  time_period {
    # Budgets must start on the first of a month.
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", plantimestamp())
  }

  notification {
    enabled        = true
    operator       = "GreaterThanOrEqualTo"
    threshold      = 50
    threshold_type = "Actual"
    contact_emails = [var.budget_contact_email]
  }

  notification {
    enabled        = true
    operator       = "GreaterThanOrEqualTo"
    threshold      = 100
    threshold_type = "Actual"
    contact_emails = [var.budget_contact_email]
  }

  notification {
    enabled        = true
    operator       = "GreaterThanOrEqualTo"
    threshold      = 100
    threshold_type = "Forecasted"
    contact_emails = [var.budget_contact_email]
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}
