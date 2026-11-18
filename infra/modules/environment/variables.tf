variable "environment" {
  description = "Environment name: dev, uat or prod."
  type        = string

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be dev, uat or prod."
  }
}

variable "resource_group_name" {
  description = "Existing resource group for this environment, created by infra/bootstrap."
  type        = string
}

variable "location" {
  description = "Azure region for every resource in this environment. All free Azure SQL databases in a subscription must share one region."
  type        = string
}

variable "sql_admin" {
  description = "Microsoft Entra principal that administers the SQL server. The server accepts Entra sign-in only, so no password exists."
  type = object({
    login_username = string
    object_id      = string
  })
}

variable "function_maximum_instance_count" {
  description = "Upper limit on Functions instances, which caps cost if something calls the API in a loop."
  type        = number
  default     = 40
}
