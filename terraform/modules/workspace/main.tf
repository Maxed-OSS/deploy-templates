# ---------------------------------------------------------------------------
# workspace module (SKELETON)
# ---------------------------------------------------------------------------
# A provider-agnostic skeleton describing the shape of a managed deployment:
# a Postgres database, an optional Redis cache, and an S3-compatible bucket.
#
# It uses only the built-in `terraform` provider stand-ins (random_*) so it
# `terraform validate`s with zero cloud credentials. To make it real, replace
# the `random_*`/`local` placeholders with your cloud provider's resources
# (e.g. aws_db_instance, aws_elasticache_cluster, aws_s3_bucket) - the
# variables and outputs are already shaped for that swap.
#
# Version constraints live in versions.tf (Terraform Registry convention).
# ---------------------------------------------------------------------------

locals {
  db_identifier    = "${var.name_prefix}-db"
  cache_identifier = "${var.name_prefix}-cache"
  common_tags = merge(
    {
      "managed-by" = "terraform"
      "module"     = "workspace"
    },
    var.tags,
  )
}

# Placeholder for the application database password. In a real deployment,
# store this in your provider's secret manager and reference it instead.
resource "random_password" "db" {
  length  = 24
  special = true
}

# --- Replace the blocks below with real provider resources -----------------
# Each null_resource documents one piece of managed infrastructure and keeps
# the skeleton valid + plannable. The triggers capture the intended config.

resource "random_id" "db" {
  byte_length = 4
  keepers = {
    identifier = local.db_identifier
    version    = var.postgres_version
    size       = var.postgres_instance_size
  }
}

resource "random_id" "cache" {
  count       = var.redis_enabled ? 1 : 0
  byte_length = 4
  keepers = {
    identifier = local.cache_identifier
  }
}

resource "random_id" "bucket" {
  byte_length = 4
  keepers = {
    bucket = var.object_storage_bucket
  }
}
