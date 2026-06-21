# Terraform

A **registry-ready** module describing a managed deployment of the same pieces
the compose stack runs locally: a Postgres database, an optional Redis cache, and
an S3-compatible bucket.

## Layout

```
terraform/
  modules/workspace/   # the reusable module (versions, variables, main, outputs, README)
  examples/local/      # a runnable example that uses only the random provider
```

The module follows Terraform Registry conventions: pinned `required_version` /
`required_providers` in [`versions.tf`](./modules/workspace/versions.tf), typed
and **validated** inputs in [`variables.tf`](./modules/workspace/variables.tf),
documented [`outputs.tf`](./modules/workspace/outputs.tf), a module
[`README.md`](./modules/workspace/README.md), and a runnable
[example](./examples/local).

## Try it

```bash
cd examples/local
terraform init
terraform validate
terraform plan
```

This plans with **no cloud credentials** because the skeleton uses the
`random` provider as a stand-in. The validated inputs (`name_prefix`,
`postgres_version`, `postgres_instance_size`, `redis_enabled`,
`object_storage_bucket`, `tags`) and outputs (`database_identifier`,
`database_password`, `cache_identifier`, `bucket_name`, `tags`) are already
shaped for a real provider.

## Consuming the module

```hcl
module "workspace" {
  source = "github.com/maxed-oss/deploy-templates//terraform/modules/workspace"
  # Once published to the Terraform Registry:
  #   source  = "maxed-oss/workspace/<provider>"
  #   version = "~> 0.1"

  name_prefix           = "acme-prod"
  object_storage_bucket = "acme-prod-documents"
}
```

## Make it real

Inside `modules/workspace/main.tf`, replace the `random_id` / `random_password`
placeholders with your cloud provider's resources, for example on AWS:

| Placeholder | Replace with |
|---|---|
| `random_id.db` | `aws_db_instance` (engine `postgres`) |
| `random_id.cache` | `aws_elasticache_cluster` (engine `redis`) |
| `random_id.bucket` | `aws_s3_bucket` |
| `random_password.db` | a secret in `aws_secretsmanager_secret` |

The inputs and outputs stay the same, so callers of the module do not change.
