output "database_identifier" {
  description = "Identifier for the provisioned Postgres database."
  value       = "${local.db_identifier}-${random_id.db.hex}"
}

output "database_password" {
  description = "Generated application database password (placeholder)."
  value       = random_password.db.result
  sensitive   = true
}

output "cache_identifier" {
  description = "Identifier for the Redis cache, or null when disabled."
  value       = var.redis_enabled ? "${local.cache_identifier}-${random_id.cache[0].hex}" : null
}

output "bucket_name" {
  description = "Name of the object-storage bucket."
  value       = var.object_storage_bucket
}

output "tags" {
  description = "Resolved tags applied to resources."
  value       = local.common_tags
}
