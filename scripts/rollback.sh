#!/usr/bin/env bash

set -euo pipefail

CURRENT_IMAGE="$(docker inspect --format='{{.Config.Image}}' homelab-app 2>/dev/null || true)"

if [[ -z "$CURRENT_IMAGE" ]]; then
    echo "ERROR: homelab-app container is not running."
    exit 1
fi

CURRENT_TAG="${CURRENT_IMAGE##*:}"
TARGET_TAG="${1:-}"

if [[ -z "$TARGET_TAG" ]]; then
    echo "Current image:"
    echo "  $CURRENT_IMAGE"
    echo
    echo "Usage:"
    echo "  $0 sha-xxxxxxxx"
    exit 1
fi

if [[ "$CURRENT_TAG" == "$TARGET_TAG" ]]; then
    echo "ERROR: Target version is already running:"
    echo "  $TARGET_TAG"
    exit 1
fi

echo "Current version:"
echo "  $CURRENT_TAG"

echo "Rollback target:"
echo "  $TARGET_TAG"

read -r -p "Continue with rollback? [y/N] " CONFIRM

if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Rollback cancelled."
    exit 0
fi

echo
echo "Starting rollback..."

./scripts/deploy.sh "$TARGET_TAG"

echo
echo "Rollback completed successfully."
echo "Current image:"
docker inspect --format='{{.Config.Image}}' homelab-app
