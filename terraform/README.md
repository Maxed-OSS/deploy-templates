# Terraform

A provider-agnostic **module skeleton** describing a managed deployment of the
same pieces the compose stack runs locally: a Postgres database, an optional
Redis cache, and an S3-compatible bucket.

## Layout

```
terraform/
  modules/workspace/   # the reusable module (variables, main, outputs)
  examples/local/      # a runnable example that uses only the random provider
```

## Try it

```bash
cd examples/local
terraform init
terraform validate
terraform plan
```

This plans with **no cloud credentials** because the skeleton uses the
`random` provider as a stand-in. The variables (`postgres_version`,
`postgres_instance_size`, `redis_enabled`, `object_storage_bucket`, `tags`) and
outputs (`database_identifier`, `database_password`, `cache_identifier`,
`bucket_name`) are already shaped for a real provider.

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
