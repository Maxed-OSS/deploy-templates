# Railway starter

Deploy the API placeholder to [Railway](https://railway.app), backed by
Railway's managed Postgres and Redis plugins plus any S3-compatible bucket.

## Steps

1. **Create a project** and add the **Postgres** and **Redis** plugins from the
   Railway dashboard. Railway injects `DATABASE_URL` and `REDIS_URL`.
2. **Add a service from this repo.** Railway reads `starters/railway/railway.json`
   (point the service config path at it, or copy it to the repo root) to build
   `compose/api/Dockerfile` and run the health-checked start command.
3. **Set the storage variables** for your bucket (Railway has no built-in S3;
   use AWS S3, Cloudflare R2, or a hosted MinIO):

   | Variable | Example |
   |---|---|
   | `S3_ENDPOINT_URL` | `https://s3.your-region.amazonaws.com` |
   | `S3_BUCKET` | `your-workspace-documents` |
   | `S3_ACCESS_KEY` | `...` |
   | `S3_SECRET_KEY` | `...` |

4. **Deploy.** Railway builds the image and runs `uvicorn ... --port $PORT`.
   The healthcheck hits `/healthz`; `/readyz` reports each dependency.

## Notes

- Railway sets `$PORT` at runtime - the start command already binds to it.
- The application database role from the local stack does not exist on Railway;
  the managed `DATABASE_URL` already grants what the app needs. Apply your own
  RLS migrations (see `compose/postgres/initdb/10-rls-bootstrap.sql` for the
  pattern) against the managed database.
