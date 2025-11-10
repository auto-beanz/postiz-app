# Deploying Postiz on Your VM

This guide walks you through deploying the Postiz monorepo application on your own VM using Docker Compose with source code builds.

## Prerequisites

- A VM with Ubuntu/Debian (or similar Linux distribution)
- Docker and Docker Compose installed
- At least 4GB RAM and 20GB disk space
- Ports 5000 (or your chosen port) open in firewall

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/gitroomhq/postiz-app.git
cd postiz-app
```

### 2. Configure Environment Variables

Copy and edit the `.env` file with your configuration:

```bash
# Edit .env with your settings
nano .env
```

**Critical settings to update:**

```env
# Your VM's IP or domain
FRONTEND_URL="http://YOUR_VM_IP:5000"
NEXT_PUBLIC_BACKEND_URL="http://YOUR_VM_IP:5000/api"

# Generate a strong JWT secret
JWT_SECRET="your-very-long-random-secret-string-here"

# Database credentials (these match docker-compose.prod.yaml)
DATABASE_URL="postgresql://postiz-user:postiz-password@postiz-postgres:5432/postiz-db-local"
REDIS_URL="redis://postiz-redis:6379"

# Storage settings
STORAGE_PROVIDER="local"
UPLOAD_DIRECTORY="/uploads"

# Add your social media API credentials
FACEBOOK_APP_ID="your-app-id"
FACEBOOK_APP_SECRET="your-app-secret"
# ... etc
```

### 3. Deploy Using the Helper Script

```bash
# Make the script executable (if not already)
chmod +x deploy.sh

# Run the deployment script
./deploy.sh
```

Choose option **1** to build and start containers.

### 4. Manual Deployment (Alternative)

If you prefer manual control:

```bash
# Build and start all containers
docker compose -f docker-compose.prod.yaml up -d --build

# View logs
docker compose -f docker-compose.prod.yaml logs -f

# Check container status
docker compose -f docker-compose.prod.yaml ps
```

## Architecture

The `docker-compose.prod.yaml` creates three services:

- **postiz**: Main application (built from your source code)
  - Frontend (Next.js) on internal port 4200
  - Backend (NestJS) on internal port 3000
  - Workers & Cron jobs (PM2 managed)
  - NGINX reverse proxy on port 5000 (exposed)
  
- **postiz-postgres**: PostgreSQL 17 database
  
- **postiz-redis**: Redis for queues and caching

## Build Process

The Dockerfile (`Dockerfile.dev`) does the following:

1. Uses Node.js 22 Alpine image
2. Installs pnpm and PM2
3. Copies your source code
4. Runs `pnpm install` to install dependencies
5. Runs `pnpm run build` to build all apps (frontend, backend, workers, cron)
6. Configures NGINX as reverse proxy
7. Starts all services with PM2

## Accessing Your Application

Once deployed, access Postiz at:

```
http://YOUR_VM_IP:5000
```

API endpoint:
```
http://YOUR_VM_IP:5000/api
```

## Managing Your Deployment

### View Logs

```bash
# All services
docker compose -f docker-compose.prod.yaml logs -f

# Specific service
docker compose -f docker-compose.prod.yaml logs -f postiz
docker compose -f docker-compose.prod.yaml logs -f postiz-postgres
```

### Restart Services

```bash
# Restart all
docker compose -f docker-compose.prod.yaml restart

# Restart specific service
docker compose -f docker-compose.prod.yaml restart postiz
```

### Stop Services

```bash
docker compose -f docker-compose.prod.yaml down
```

### Rebuild After Code Changes

```bash
# Stop containers
docker compose -f docker-compose.prod.yaml down

# Rebuild and start
docker compose -f docker-compose.prod.yaml up -d --build
```

### Database Management

```bash
# Access PostgreSQL
docker exec -it postiz-postgres psql -U postiz-user -d postiz-db-local

# Backup database
docker exec postiz-postgres pg_dump -U postiz-user postiz-db-local > backup.sql

# Restore database
docker exec -i postiz-postgres psql -U postiz-user postiz-db-local < backup.sql
```

### View Running Processes Inside Container

```bash
# Access the container
docker exec -it postiz sh

# View PM2 processes
pm2 list

# View PM2 logs
pm2 logs
```

## Production Recommendations

### 1. Use a Domain Name and SSL

Set up a reverse proxy (like Nginx or Caddy) on your VM:

```nginx
server {
    listen 80;
    server_name postiz.yourdomain.com;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Then use Certbot for SSL:
```bash
sudo certbot --nginx -d postiz.yourdomain.com
```

### 2. Change Default Passwords

Edit `docker-compose.prod.yaml` to change PostgreSQL credentials:

```yaml
environment:
  POSTGRES_PASSWORD: your-strong-password
  POSTGRES_USER: your-username
  POSTGRES_DB: postiz-db
```

Update `.env` DATABASE_URL accordingly.

### 3. Set Up Backups

Create a backup script:

```bash
#!/bin/bash
BACKUP_DIR="/backup/postiz"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup database
docker exec postiz-postgres pg_dump -U postiz-user postiz-db-local > "$BACKUP_DIR/db_$DATE.sql"

# Backup uploads
docker run --rm -v postiz-uploads:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/uploads_$DATE.tar.gz -C /data .

# Keep only last 7 days
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
```

Add to crontab:
```bash
0 2 * * * /path/to/backup-script.sh
```

### 4. Configure Firewall

```bash
# Ubuntu/Debian with ufw
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 22/tcp  # SSH
sudo ufw enable
```

### 5. Monitor Resources

```bash
# View container resource usage
docker stats

# View disk usage
docker system df
```

### 6. Update Strategy

```bash
# Pull latest code
git pull origin main

# Rebuild with zero downtime (if you have a load balancer)
docker compose -f docker-compose.prod.yaml up -d --build --no-deps postiz

# Or standard rebuild
docker compose -f docker-compose.prod.yaml down
docker compose -f docker-compose.prod.yaml up -d --build
```

## Troubleshooting

### Container Won't Start

Check logs:
```bash
docker compose -f docker-compose.prod.yaml logs postiz
```

### Database Connection Issues

Verify database is healthy:
```bash
docker compose -f docker-compose.prod.yaml ps
docker logs postiz-postgres
```

### Build Fails (Out of Memory)

Increase Docker memory limit or build on a machine with more RAM, then push the image to a registry.

### Can't Access from Outside VM

- Check firewall rules
- Verify port 5000 is exposed
- Ensure `FRONTEND_URL` and `NEXT_PUBLIC_BACKEND_URL` use your public IP or domain

## File Structure

```
postiz-app/
├── docker-compose.prod.yaml    # Production Docker Compose file
├── Dockerfile.dev              # Dockerfile for building the app
├── deploy.sh                   # Deployment helper script
├── .env                        # Environment configuration
├── var/docker/nginx.conf       # NGINX configuration
└── apps/                       # Application source code
    ├── frontend/               # Next.js frontend
    ├── backend/                # NestJS backend
    ├── workers/                # Background workers
    └── cron/                   # Scheduled tasks
```

## Getting Help

- Documentation: https://docs.postiz.com/
- Issues: https://github.com/gitroomhq/postiz-app/issues

## Environment Variables Reference

See `.env` file for all available configuration options including:

- Social media API credentials (Facebook, X, LinkedIn, etc.)
- Storage providers (Local, Cloudflare R2)
- Email settings (Resend)
- Payment settings (Stripe)
- OAuth providers
- Short link services
