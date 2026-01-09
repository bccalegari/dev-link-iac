# devLink IaC Development Environment

This project sets up a local development environment for the devLink application using Infrastructure as Code (IaC) principles. It leverages Kubernetes, Docker, Terraform, and supporting tools to simulate a production-like environment locally, enabling consistent development and testing workflows.

> Tested on Windows 11 with WSL2. Other operating systems may work but could require adjustments.

> Pipelines require GitHub App credentials to be configured in Jenkins.  
> Because this project relies on personal repositories, pipelines do not work out of the box.

## TL;DR

### First Time Setup
```bash
minikube start
minikube addons disable ingress # Only if ingress addon is enabled
cp .env.example .env
PUSH_IMAGES=true ./deploy.sh
```
### Subsequent Runs
```bash
./deploy.sh
```
### Access

All services exposed via ingress follow the pattern:
```
http://<service-name>.devlink.localhost
```
Example:
- Jenkins: http://jenkins.devlink.localhost

## About This Project

The environment is designed to:

- Run containerized devLink services locally using Kubernetes
- Provide a local Docker registry to speed up image builds
- Use Terraform to declaratively provision infrastructure components
- Centralize build and deployment flows with Buildah and Jenkins
- Persist configuration and job data for reliable development

This setup allows developers to simulate production-like scenarios locally without relying on cloud infrastructure.

## Key Components

| Component                    | Purpose                                                                    |
|-----------------------------|----------------------------------------------------------------------------|
| **Kubernetes Cluster**       | Orchestrates containers and services locally (Minikube or Docker Desktop). |
| **Docker / Docker Desktop**  | Builds and runs containerized applications.                                |
| **Terraform**                | Declarative provisioning of infrastructure resources.                      |
| **jq**                       | CLI tool for processing JSON in scripts.                                   |
| **Nginx Ingress Controller** | Routes HTTP traffic to services within the cluster.                        |
| **Docker Registry**          | Stores images locally to reduce external dependencies.                     |
| **Buildah**                  | Builds OCI/Docker images without requiring a Docker daemon.                |
| **Jenkins (JCASC)**          | CI/CD pipelines with persistent configuration and job storage.             |

## Architecture Overview

The architecture consists of a local Kubernetes cluster hosting multiple services.

### Nginx Ingress Controller

Manages external HTTP access to services within the cluster.

> Version used: 1.14.1 (project-managed, not Minikube addon)

If you are using Minikube, disable the default ingress addon to avoid conflicts:
```bash
minikube addons disable ingress
```

### Docker Registry

A local Docker registry used to store and retrieve images, speeding up build and deployment cycles.

- Exposed via NodePort on port **32000**
- NodePort is used to allow external access without TLS for local development
- Used by Buildah and Kubernetes for image storage

#### Secrets

- htpasswd authentication
- Docker config for push/pull
- Basic auth for registry UI

#### Access
```
http://localhost:32000
```

### Buildah Job

Buildah is used to build Docker/OCI images inside Kubernetes without requiring a Docker daemon.

| Image               | Purpose                                       |
|--------------------|-----------------------------------------------|
| **terraform-k8s**   | Runs Terraform and kubectl                    |
| **devLink Jenkins** | Jenkins with preinstalled plugins and configs |

> Note: Buildah job is not managed by Terraform, `deploy.sh` handles its with `./infra/buildah/build.sh` script that manages dynamic k8s resources.

### Jenkins

Jenkins manages CI/CD pipelines for building and deploying devLink services and is deployed using Jenkins Configuration as Code (JCASC).

> Exposed via Ingress.

#### Secrets

- Jenkins admin user credentials

#### Access
```
http://jenkins.devlink.localhost
```

## Deployment Flow

1. Terraform provisions infrastructure components:
    - Nginx Ingress Controller
    - Docker Registry
    - Jenkins
    - Persistent volumes and secrets

2. On the first deployment:
    - A Buildah job builds container images
    - Images are pushed to the local registry
    - Jenkins waits for required images before starting

## deploy.sh

The `deploy.sh` script automates the deployment process, handling both first-time setups and subsequent deployments, providing terraform initialization, planning, and application and managing other tasks and scripts.

| Variable     | Description                                | Default |
|-------------|--------------------------------------------|---------|
| PUSH_IMAGES | Builds and pushes images to local registry | false   |

## Prerequisites

- **Minikube** or **Docker Desktop Kubernetes**
- **Docker / Docker Desktop**
- **Terraform**
- **jq**

### Host Entry
```
127.0.0.1 jenkins.devlink.localhost
```
> If using Minikube, run `minikube tunnel` to expose LoadBalancer services.

## Usage

Start your Kubernetes cluster (Minikube or Docker Desktop).

## First Time Setup

Copy the example environment variables file:
```bash
cp .env.example .env
```
No changes are required for local development unless defaults need adjustment.

Run the deployment script:
```bash
PUSH_IMAGES=true ./deploy.sh
```

## Subsequent Deployments
```bash
./deploy.sh
```

## Troubleshooting

### Ingress Not Working

- Ensure the Minikube ingress addon is disabled
- Verify ingress controller pods are running

### Cannot Push Images to Registry

- Check registry NodePort (32000)
- Verify Docker authentication secrets
- If using Minikube, ensure Docker is pointing to the Minikube daemon

### Jenkins Not Accessible

- Check `/etc/hosts` entry
- Verify ingress resources
- Check Jenkins pod logs

## Contributing
Contributions are welcome! Open GitHub issues or pull requests.


## License

MIT License. See [LICENSE](LICENSE.md).

---

Built with ❤️ by Bruno Calegari