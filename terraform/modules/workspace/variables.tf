variable "name_prefix" {
  description = "Prefix applied to every resource name (e.g. \"acme-prod\"). Lowercase letters, digits, and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,38}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-40 chars, lowercase alphanumeric or hyphen, starting with a letter."
  }
}

variable "postgres_version" {
  description = "Major Postgres version to provision."
  type        = string
  default     = "16"

  validation {
    condition     = can(regex("^[0-9]{2}$", var.postgres_version))
    error_message = "postgres_version must be a two-digit major version, e.g. \"16\"."
  }
}

variable "postgres_instance_size" {
  description = "Provider-agnostic instance size label for the database (small, medium, or large)."
  type        = string
  default     = "small"

  validation {
    condition     = contains(["small", "medium", "large"], var.postgres_instance_size)
    error_message = "postgres_instance_size must be one of: small, medium, large."
  }
}

variable "redis_enabled" {
  description = "Whether to provision a Redis cache."
  type        = bool
  default     = true
}

variable "object_storage_bucket" {
  description = "Name of the S3-compatible bucket for documents. Must be a valid S3 bucket name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.object_storage_bucket))
    error_message = "object_storage_bucket must be 3-63 chars, lowercase alphanumeric, dots, or hyphens (S3 naming rules)."
  }
}

variable "tags" {
  description = "Tags/labels applied to all resources."
  type        = map(string)
  default     = {}
}
