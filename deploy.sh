#!/bin/bash

# Postiz Deployment Script
# This script helps you deploy Postiz on your VM

set -e

# Check if we need sudo for Docker commands
DOCKER_CMD="docker"
if ! docker ps >/dev/null 2>&1; then
    if sudo docker ps >/dev/null 2>&1; then
        echo "ℹ️  Docker requires sudo privileges"
        DOCKER_CMD="sudo docker"
    else
        echo "❌ Error: Cannot access Docker daemon"
        echo "Please ensure Docker is running and you have permissions"
        exit 1
    fi
fi

echo "======================================"
echo "Postiz Deployment Script"
echo "======================================"
echo ""

# Check if .env file exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found!"
    echo "Please create a .env file with your configuration."
    echo "You can copy .env.example if available."
    exit 1
fi

echo "✅ Found .env file"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed!"
    echo "Please install Docker first: https://docs.docker.com/engine/install/"
    exit 1
fi

echo "✅ Docker is installed"

# Check if Docker Compose is available
if ! docker compose version &> /dev/null; then
    echo "❌ Error: Docker Compose is not available!"
    echo "Please install Docker Compose: https://docs.docker.com/compose/install/"
    exit 1
fi

echo "✅ Docker Compose is available"

# Set up docker compose command with sudo if needed
if [ "$DOCKER_CMD" = "sudo docker" ]; then
    COMPOSE_CMD="sudo docker compose"
else
    COMPOSE_CMD="docker compose"
fi

echo ""

# Ask user what they want to do
echo "What would you like to do?"
echo "1) Build and start containers (fresh build)"
echo "2) Start containers (use existing build)"
echo "3) Stop containers"
echo "4) View logs"
echo "5) Restart containers"
echo "6) Clean up (stop and remove containers, volumes)"
echo ""
read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo ""
        echo "🔨 Building and starting Postiz..."
        $COMPOSE_CMD -f docker-compose.prod.yaml up -d --build
        echo ""
        echo "✅ Build complete! Waiting for services to be healthy..."
        sleep 10
        $COMPOSE_CMD -f docker-compose.prod.yaml ps
        echo ""
        echo "🎉 Postiz is now running!"
        echo "📍 Access it at: http://localhost:5000"
        echo "📝 View logs: $COMPOSE_CMD -f docker-compose.prod.yaml logs -f"
        ;;
    2)
        echo ""
        echo "▶️  Starting Postiz containers..."
        $COMPOSE_CMD -f docker-compose.prod.yaml up -d
        echo ""
        echo "✅ Containers started!"
        $COMPOSE_CMD -f docker-compose.prod.yaml ps
        ;;
    3)
        echo ""
        echo "⏹️  Stopping Postiz containers..."
        $COMPOSE_CMD -f docker-compose.prod.yaml down
        echo "✅ Containers stopped!"
        ;;
    4)
        echo ""
        echo "📋 Showing logs (Ctrl+C to exit)..."
        $COMPOSE_CMD -f docker-compose.prod.yaml logs -f
        ;;
    5)
        echo ""
        echo "🔄 Restarting Postiz containers..."
        $COMPOSE_CMD -f docker-compose.prod.yaml restart
        echo "✅ Containers restarted!"
        ;;
    6)
        echo ""
        read -p "⚠️  This will remove all containers and volumes. Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            echo "🧹 Cleaning up..."
            $COMPOSE_CMD -f docker-compose.prod.yaml down -v
            echo "✅ Cleanup complete!"
        else
            echo "Cancelled."
        fi
        ;;
    *)
        echo "❌ Invalid choice!"
        exit 1
        ;;
esac
