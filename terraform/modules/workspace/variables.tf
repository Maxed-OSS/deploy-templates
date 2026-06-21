variable "name_prefix" {
  description = "Prefix applied to every resource name (e.g. \"acme-prod\")."
  type        = string
}

variable "postgres_version" {
  description = "Major Postgres version to provision."
  type        = string
  default     = "16"
}

variable "postgres_instance_size" {
  description = "Provider-agnostic instance size label for the database."
  type        = string
  default     = "small"
}

variable "redis_enabled" {
  description = "Whether to provision a Redis cache."
  type        = bool
  default     = true
}

variable "object_storage_bucket" {
  description = "Name of the S3-compatible bucket for documents."
  type        = string
}

variable "tags" {
  description = "Tags/labels applied to all resources."
  type        = map(string)
  default     = {}
}
