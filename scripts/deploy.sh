#!/usr/bin/env bash

set -euo pipefail

cd /opt/homelab-app

IMAGE_TAG="${1:-}"

if [[ -z "$IMAGE_TAG" ]]; then
    echo "ERROR: image tag is required"
    echo "Usage: $0 sha-xxxxxxxx"
    exit 1
fi

echo "Deploying image:"
echo "ghcr.io/etherian3/homelab-app:${IMAGE_TAG}"

export APP_IMAGE_TAG="$IMAGE_TAG"

docker compose pull app
docker compose up -d app

echo "Waiting for application health..."

for i in {1..30}; do
    STATUS="$(docker inspect --format='{{.State.Health.Status}}' homelab-app 2>/dev/null || true)"

    if [[ "$STATUS" == "healthy" ]]; then
        echo "Application is healthy."
        break
    fi

    if [[ "$STATUS" == "unhealthy" ]]; then
        echo "ERROR: Application is unhealthy."
        exit 1
    fi

    sleep 2
done

STATUS="$(docker inspect --format='{{.State.Health.Status}}' homelab-app)"

if [[ "$STATUS" != "healthy" ]]; then
    echo "ERROR: Application did not become healthy."
    exit 1
fi

echo "Deployment successful."
echo "Running image:"
docker inspect --format='{{.Config.Image}}' homelab-app
