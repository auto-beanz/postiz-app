#!/bin/bash

# Docker Build with Cache Script
# This script helps you build Docker images with optimal caching

set -e

echo "======================================"
echo "Docker Build with Cache Optimization"
echo "======================================"
echo ""

# Enable BuildKit
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

echo "✅ BuildKit enabled for faster builds and better caching"
echo ""

# Ask user what they want to do
echo "Build options:"
echo "1) Build with cache (recommended)"
echo "2) Build without cache (clean build)"
echo "3) Prune build cache"
echo ""
read -p "Enter your choice (1-3): " choice

case $choice in
    1)
        echo ""
        echo "🔨 Building with cache optimization..."
        echo "This will reuse cached layers from previous builds."
        echo ""
        
        DOCKER_BUILDKIT=1 docker compose -f docker-compose.prod.yaml build --progress=plain
        
        echo ""
        echo "✅ Build complete!"
        echo ""
        read -p "Start containers now? (yes/no): " start
        if [ "$start" = "yes" ]; then
            docker compose -f docker-compose.prod.yaml up -d
            echo "✅ Containers started!"
        fi
        ;;
    2)
        echo ""
        echo "🧹 Building without cache (clean build)..."
        echo "⚠️  This will take longer but ensures a fresh build."
        echo ""
        
        DOCKER_BUILDKIT=1 docker compose -f docker-compose.prod.yaml build --no-cache --progress=plain
        
        echo ""
        echo "✅ Clean build complete!"
        echo ""
        read -p "Start containers now? (yes/no): " start
        if [ "$start" = "yes" ]; then
            docker compose -f docker-compose.prod.yaml up -d
            echo "✅ Containers started!"
        fi
        ;;
    3)
        echo ""
        echo "🗑️  Pruning build cache..."
        docker builder prune -af
        echo "✅ Build cache cleared!"
        echo ""
        echo "Cache statistics:"
        docker system df
        ;;
    *)
        echo "❌ Invalid choice!"
        exit 1
        ;;
esac

echo ""
echo "======================================"
echo "Cache Information"
echo "======================================"
docker system df
echo ""
echo "💡 Tips:"
echo "- First build will be slow (5-10 min)"
echo "- Subsequent builds reuse cache (1-3 min)"
echo "- Only changed layers are rebuilt"
echo "- pnpm dependencies are cached separately"
