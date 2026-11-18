variable "subscription_id" {
  description = "The Setlist pay-as-you-go subscription. Required, so the bootstrap never runs against another subscription by accident."
  type        = string
}

variable "tenant_id" {
  description = "The Microsoft Entra tenant that owns the subscription."
  type        = string
}

variable "location" {
  description = "Region for the state account and resource groups. Keep it the same as the environments' location."
  type        = string
  default     = "eastus2"
}

variable "github_repository" {
  description = "owner/name of the repository whose GitHub Environments may sign in."
  type        = string
  default     = "AdamTheAnalyst291/Setlist"
}

variable "environments" {
  description = "Environments to set up. Each gets a resource group, a state container and a deploy identity."
  type        = set(string)
  default     = ["dev"]

  validation {
    condition     = alltrue([for e in var.environments : contains(["dev", "uat", "prod"], e)])
    error_message = "environments may contain only dev, uat and prod."
  }
}

variable "budget_amount" {
  description = "Monthly budget for the whole subscription, in the billing currency."
  type        = number
  default     = 5
}

variable "budget_contact_email" {
  description = "Where budget alerts are emailed. Set it in terraform.tfvars, which git ignores."
  type        = string
}
