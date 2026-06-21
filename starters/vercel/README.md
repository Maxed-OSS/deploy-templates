# Vercel starter

Host a static (or framework) front-end on [Vercel](https://vercel.com) that
talks to the API deployed elsewhere (Railway, your own infra, etc.).

## How it works

`vercel.json` does two things:

1. **Serves** the contents of `public/` (replace with your real build output and
   update `buildCommand` / `outputDirectory`).
2. **Rewrites** `/api/*` to your backend host so the browser calls a same-origin
   path and Vercel proxies it to the API. Edit the `destination` in the rewrite
   to point at your deployed API.

## Steps

1. Set the rewrite `destination` in `vercel.json` to your API URL.
2. `vercel` (or connect the repo in the Vercel dashboard) with this directory as
   the project root.
3. Open the deployment - `public/index.html` pings `/api/healthz` to confirm the
   proxy reaches your backend.

## Security headers

The starter ships baseline response headers (`X-Content-Type-Options`,
`Referrer-Policy`). Add `Content-Security-Policy` once your asset origins are
known.
