# CI/CD Pipeline

## Overview

The homelab application uses GitHub Actions to automate application testing,
container image building, deployment, health verification, and automatic rollback.

The deployment architecture is:

GitHub Push
    ↓
Test
    ↓
Build Docker Image
    ↓
Push to GitHub Container Registry
    ↓
Self-hosted Runner
    ↓
Deploy immutable SHA image
    ↓
Health Check
    ↓
Success → Production
Failure → Automatic Rollback

## Pipeline Stages

### 1. Test

Every push and pull request runs application validation.

The pipeline:

- checks out the repository
- installs Python 3.12
- installs application dependencies
- validates that the FastAPI application can be imported

### 2. Build

After tests pass, GitHub Actions builds the Docker image.

Images are pushed to GitHub Container Registry (GHCR).

Images are tagged using the Git commit SHA.

Example:

    ghcr.io/etherian3/homelab-app:sha-2d6ce1f

Using immutable SHA tags makes deployments reproducible and allows
specific application versions to be deployed or rolled back.

### 3. Deployment

Deployment runs through a self-hosted GitHub Actions runner located on
the management VM.

The runner connects to:

    application-01 (192.168.1.111)

The application is deployed using:

    /opt/homelab-app/scripts/deploy.sh

The deployment script:

1. Pulls the requested image
2. Starts the application container
3. Waits for the Docker health check
4. Fails if the application does not become healthy

### 4. Health Verification

The application container has a Docker health check.

The deployment is considered successful only when:

    healthy

The deployed image is also verified after deployment.

### 5. Automatic Rollback

The pipeline stores the currently running immutable SHA image before
deploying the new version.

If deployment fails or the health check fails, the pipeline automatically
deploys the previously running image.

Rollback therefore does not depend on rebuilding the previous version.

## Rollback Test

An intentional deployment failure was performed using a non-existent image:

    sha-deadbee

The deployment failed while attempting to pull the image.

The pipeline then automatically rolled back to the previous production image.

The final production state was verified with:

    docker inspect --format='{{.Config.Image}}' homelab-app

    docker inspect --format='{{.State.Health.Status}}' homelab-app

The application returned:

    {"application":"homelab-app","status":"running"}

The container remained healthy after rollback.

## Failure Recovery Flow

Normal deployment:

    Git Push
       ↓
    Test
       ↓
    Build
       ↓
    Push Image
       ↓
    Deploy SHA
       ↓
    Health Check
       ↓
    Production

Failed deployment:

    Git Push
       ↓
    Test
       ↓
    Build
       ↓
    Push Image
       ↓
    Deploy SHA
       ↓
    ❌ Failure
       ↓
    Automatic Rollback
       ↓
    Previous SHA
       ↓
    Health Check
       ↓
    ✅ Production Healthy

## Design Decisions

### Immutable Images

Production deployments use Git SHA image tags instead of relying only on
the `latest` tag.

This provides:

- reproducibility
- traceability
- deterministic rollback
- easier incident investigation

### Self-hosted Runner

The application VM is located on a private LAN and cannot be reached
directly by GitHub-hosted runners.

A self-hosted runner on the management VM provides controlled access to
the private infrastructure.

### Health-based Deployment

A deployment is not considered successful merely because Docker starts
the container.

The application must pass its health check before the deployment is
considered successful.

## Security Considerations

The application container does not expose port 8000 directly to the LAN.

Traffic enters through Traefik on port 80.

Secrets such as database credentials are stored outside Git and are not
committed to the repository.

SSH access uses key-based authentication.

The application VM is protected by UFW.
