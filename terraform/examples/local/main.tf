# Example use of the workspace module.
# Run from this directory:
#   terraform init
#   terraform plan
#
# This example uses only the random provider, so it plans with no cloud
# credentials. Swap the module's internals for real provider resources to
# deploy for real.

terraform {
  required_version = ">= 1.3.0"
}

module "workspace" {
  source = "../../modules/workspace"

  name_prefix            = "demo-local"
  postgres_version       = "16"
  postgres_instance_size = "small"
  redis_enabled          = true
  object_storage_bucket  = "demo-local-documents"

  tags = {
    environment = "example"
    owner       = "platform"
  }
}

output "database_identifier" {
  description = "Identifier for the provisioned Postgres database."
  value       = module.workspace.database_identifier
}

output "cache_identifier" {
  description = "Identifier for the Redis cache, or null when disabled."
  value       = module.workspace.cache_identifier
}

output "bucket_name" {
  description = "Name of the object-storage bucket."
  value       = module.workspace.bucket_name
}

output "tags" {
  description = "Resolved tags applied to resources."
  value       = module.workspace.tags
}
