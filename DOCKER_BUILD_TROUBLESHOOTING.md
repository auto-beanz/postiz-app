# Docker Build & Deployment Guide

## Important: Environment Variables for Docker Build

When building with Docker, Next.js requires certain environment variables at **build time** (not just runtime).

### Required Build-Time Variables

Make sure these are set in your `.env` file:

```bash
# CRITICAL: This must be set for Docker builds
NEXT_PUBLIC_BACKEND_URL="http://YOUR_VM_IP:5000/api"

# Optional but recommended
NEXT_PUBLIC_UPLOAD_STATIC_DIRECTORY=""
NEXT_PUBLIC_SENTRY_DSN=""
SENTRY_ORG=""
SENTRY_PROJECT=""
SENTRY_AUTH_TOKEN=""
```

### Quick Fix for Current Error

The build is failing because `NEXT_PUBLIC_BACKEND_URL` is not properly set. 

**Option 1: Update your .env file (Recommended)**

Edit your `.env` file and ensure this line exists:
```bash
NEXT_PUBLIC_BACKEND_URL="http://localhost:5000/api"
# Or use your VM's IP/domain:
# NEXT_PUBLIC_BACKEND_URL="http://YOUR_VM_IP:5000/api"
```

**Option 2: Set environment variable before build**

```bash
export NEXT_PUBLIC_BACKEND_URL="http://localhost:5000/api"
./deploy.sh
```

**Option 3: Edit docker-compose.prod.yaml directly**

Change the default in the args section if your .env doesn't have this variable.

### Rebuild

After setting the environment variable:

```bash
./deploy.sh
# Choose option 1
```

Or manually:

```bash
sudo docker compose -f docker-compose.prod.yaml up -d --build
```

## Why This Happens

Next.js is a **static site generator** that needs to know the API URL at build time to:
- Generate static pages
- Configure API routes
- Set up redirects and rewrites

Environment variables prefixed with `NEXT_PUBLIC_` are baked into the JavaScript bundle during build.

## Troubleshooting

If build still fails, check:

1. `.env` file exists and has `NEXT_PUBLIC_BACKEND_URL`
2. The URL format is correct (include http:// or https://)
3. Docker can read the .env file (check file permissions)

View build logs:
```bash
sudo docker compose -f docker-compose.prod.yaml build --progress=plain
```
