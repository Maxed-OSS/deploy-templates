# workspace (Terraform module)

Provider-agnostic module describing a managed deployment of the same pieces the
compose stack runs locally: a **Postgres database**, an optional **Redis cache**,
and an **S3-compatible bucket**.

It ships as a runnable *skeleton*: it uses only the `random` provider so it
`terraform validate`s and `plan`s with **zero cloud credentials**. The variables
and outputs are shaped so you can swap the `random_*` placeholders for real
provider resources (AWS, GCP, etc.) without changing any caller.

## Usage

```hcl
module "workspace" {
  source  = "github.com/maxed-oss/deploy-templates//terraform/modules/workspace"
  # When published to the Terraform Registry:
  #   source  = "maxed-oss/workspace/<provider>"
  #   version = "~> 0.1"

  name_prefix            = "acme-prod"
  postgres_version       = "16"
  postgres_instance_size = "small"
  redis_enabled          = true
  object_storage_bucket  = "acme-prod-documents"

  tags = {
    environment = "production"
    owner       = "platform"
  }
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3.0 |
| random | >= 3.0.0 |

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|:---:|
| `name_prefix` | Prefix applied to every resource name. Lowercase, 3-40 chars, starts with a letter. | `string` | n/a | yes |
| `postgres_version` | Major Postgres version (two digits). | `string` | `"16"` | no |
| `postgres_instance_size` | Instance size label: `small`, `medium`, or `large`. | `string` | `"small"` | no |
| `redis_enabled` | Whether to provision a Redis cache. | `bool` | `true` | no |
| `object_storage_bucket` | S3-compatible bucket name (S3 naming rules). | `string` | n/a | yes |
| `tags` | Tags/labels applied to all resources. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `database_identifier` | Identifier for the provisioned Postgres database. |
| `database_password` | Generated application database password (placeholder, `sensitive`). |
| `cache_identifier` | Identifier for the Redis cache, or `null` when disabled. |
| `bucket_name` | Name of the object-storage bucket. |
| `tags` | Resolved tags applied to resources. |

## Making it real

Replace the placeholders in `main.tf` with provider resources, for example on AWS:

| Placeholder | Replace with |
|---|---|
| `random_id.db` | `aws_db_instance` (engine `postgres`) |
| `random_id.cache` | `aws_elasticache_cluster` (engine `redis`) |
| `random_id.bucket` | `aws_s3_bucket` |
| `random_password.db` | a secret in `aws_secretsmanager_secret` |

The inputs and outputs stay the same, so callers of the module do not change.

## Example

A runnable example that plans with no cloud credentials lives in
[`../../examples/local`](../../examples/local).
