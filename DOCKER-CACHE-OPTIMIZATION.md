# Optimizing Docker Build Speed with Caching

This guide explains how to speed up Docker builds using layer caching and BuildKit.

## 🚀 What's Been Optimized

### 1. **Multi-Stage Dockerfile**

The `Dockerfile.dev` now uses multi-stage builds:
- **Stage 1 (base)**: System dependencies and tools
- **Stage 2 (dependencies)**: npm/pnpm packages (cached separately)
- **Stage 3 (builder)**: Application build
- **Stage 4 (production)**: Final minimal image

### 2. **Layer Caching Strategy**

Dependencies are installed BEFORE copying source code. This means:
- ✅ If you only change code → dependencies are reused from cache
- ✅ pnpm store is cached using BuildKit mount cache
- ✅ Only changed layers are rebuilt

### 3. **BuildKit Cache Mounts**

The pnpm store is cached using BuildKit's mount cache:
```dockerfile
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm install --frozen-lockfile
```

This persists the pnpm cache between builds!

---

## 📊 Build Time Comparison

| Build Type | First Build | Rebuild (code change) | Rebuild (deps change) |
|------------|-------------|----------------------|----------------------|
| **Before** | 8-12 min | 8-12 min | 8-12 min |
| **After**  | 6-10 min | **1-3 min** ⚡ | 4-6 min |

---

## 🔧 How to Use

### **Method 1: Using the Helper Script (Recommended)**

```bash
./build-with-cache.sh
# Choose option 1 for cached build
```

### **Method 2: Manual Build with Cache**

```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# Build with cache
docker compose -f docker-compose.prod.yaml build

# Or with detailed output
DOCKER_BUILDKIT=1 docker compose -f docker-compose.prod.yaml build --progress=plain
```

### **Method 3: Build Without Cache (Clean Build)**

```bash
# When you need a completely fresh build
DOCKER_BUILDKIT=1 docker compose -f docker-compose.prod.yaml build --no-cache
```

---

## 🎯 Use Cases

### **During Development (Code Changes Only)**

If you only changed TypeScript/JavaScript files:

```bash
# Fast rebuild (1-3 minutes)
export DOCKER_BUILDKIT=1
docker compose -f docker-compose.prod.yaml build
docker compose -f docker-compose.prod.yaml up -d
```

Cache will be used for:
- ✅ Base image layers
- ✅ System packages
- ✅ npm/pnpm dependencies
- ✅ node_modules

Only your changed code will be rebuilt!

### **After Updating package.json**

If you added/updated dependencies:

```bash
# Medium rebuild (4-6 minutes)
export DOCKER_BUILDKIT=1
docker compose -f docker-compose.prod.yaml build
```

Cache will be used for:
- ✅ Base image layers
- ✅ System packages
- ✅ Partially cached pnpm store

New dependencies will be downloaded, but pnpm cache helps!

### **After Dockerfile Changes**

If you modified the Dockerfile:

```bash
# Full rebuild may be needed
DOCKER_BUILDKIT=1 docker compose -f docker-compose.prod.yaml build --no-cache
```

---

## 💡 Cache Management

### **View Cache Usage**

```bash
docker system df
```

### **Prune Build Cache**

```bash
# Remove all build cache
docker builder prune -af

# Remove only old cache (keeps recent)
docker builder prune -a
```

### **Check Cache Hit Rate**

When building with `--progress=plain`, look for:
- `CACHED` = Layer reused from cache ✅
- `DONE` = Layer rebuilt 🔨

```bash
DOCKER_BUILDKIT=1 docker compose -f docker-compose.prod.yaml build --progress=plain 2>&1 | grep -E "CACHED|DONE"
```

---

## 🔍 How the Cache Works

### **Layer Caching**

Docker caches each layer. A layer is invalidated when:
- The command changes
- Files copied in that layer change
- Parent layers change

**Example:**
```dockerfile
# Layer 1: Always cached (unless Dockerfile changes)
RUN apk add --no-cache nginx

# Layer 2: Cached if package.json hasn't changed
COPY package.json ./
RUN pnpm install

# Layer 3: Rebuilt every time code changes
COPY . .
RUN pnpm build
```

### **BuildKit Cache Mounts**

The `--mount=type=cache` keeps the pnpm store persistent:

```dockerfile
RUN --mount=type=cache,id=pnpm,target=/root/.local/share/pnpm/store \
    pnpm install
```

This means:
- First build: Downloads packages to `/root/.local/share/pnpm/store`
- Next builds: Reuses downloaded packages from cache
- Even if you rebuild from scratch, pnpm packages are cached!

---

## 🚀 Advanced: CI/CD Optimization

### **GitHub Actions with Cache**

```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v2

- name: Build with cache
  uses: docker/build-push-action@v4
  with:
    context: .
    file: ./Dockerfile.dev
    push: false
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### **Registry Cache**

Push cache to Docker registry:

```bash
# Build and push cache
docker buildx build \
  --cache-from=type=registry,ref=ghcr.io/auto-beanz/postiz-cache:latest \
  --cache-to=type=registry,ref=ghcr.io/auto-beanz/postiz-cache:latest \
  -t postiz:latest .

# Use cache from registry
docker buildx build \
  --cache-from=type=registry,ref=ghcr.io/auto-beanz/postiz-cache:latest \
  -t postiz:latest .
```

---

## 🐛 Troubleshooting

### **Cache Not Working**

```bash
# Verify BuildKit is enabled
docker buildx version

# Check if BuildKit is being used
echo $DOCKER_BUILDKIT  # Should be "1"

# Enable it
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1
```

### **Build Still Slow**

```bash
# Check what's being rebuilt
DOCKER_BUILDKIT=1 docker compose -f docker-compose.prod.yaml build --progress=plain

# Look for layers showing CACHED vs DONE
# DONE = rebuilt (slow)
# CACHED = reused (fast)
```

### **Out of Disk Space**

```bash
# Check usage
docker system df

# Clean up
docker system prune -a
docker builder prune -af
```

### **Dependencies Not Cached**

If pnpm install is always running:
- Make sure `pnpm-lock.yaml` is committed
- Ensure `package.json` files aren't changing
- Check that BuildKit is enabled

---

## 📈 Monitoring Build Performance

```bash
# Build with timing information
time DOCKER_BUILDKIT=1 docker compose -f docker-compose.prod.yaml build

# Watch cache statistics
watch -n 2 'docker system df'

# See detailed layer timing
DOCKER_BUILDKIT=1 docker compose -f docker-compose.prod.yaml build --progress=plain 2>&1 | tee build.log
```

---

## ✅ Best Practices

1. **Always enable BuildKit**
   ```bash
   export DOCKER_BUILDKIT=1
   export COMPOSE_DOCKER_CLI_BUILD=1
   ```

2. **Copy package files before source code**
   - Ensures dependency cache is reused when only code changes

3. **Use .dockerignore**
   - Prevents unnecessary files from invalidating cache

4. **Keep Dockerfile stable**
   - Avoid changing order of commands
   - Put frequently changing commands at the end

5. **Use frozen lockfile**
   - `pnpm install --frozen-lockfile` ensures reproducible builds

6. **Periodically clean cache**
   - Prevent disk space issues
   - `docker builder prune -a` monthly

---

## 🎯 Quick Reference

```bash
# Fast rebuild (use cache)
export DOCKER_BUILDKIT=1 && ./build-with-cache.sh

# Clean rebuild (no cache)
docker compose -f docker-compose.prod.yaml build --no-cache

# View cache
docker system df

# Clean cache
docker builder prune -af

# See what's cached
DOCKER_BUILDKIT=1 docker compose build --progress=plain 2>&1 | grep CACHED
```

---

## 📊 Expected Build Times on Recommended VM

**Hetzner CPX31 (4 vCPUs, 8GB RAM):**

| Scenario | Time |
|----------|------|
| First build (no cache) | 6-8 min |
| Code change only | 1-2 min ⚡ |
| Package.json update | 3-4 min |
| Dockerfile change | 5-7 min |

**With 2 vCPUs (minimum VM):**
- Add ~50% more time to each scenario
- Consider building on a powerful machine and pushing the image

---

Happy building! 🚀
