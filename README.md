# DevOps Engineer — E-Commerce Project

A complete DevOps solution for deploying a full-stack e-commerce application (Angular + Spring Boot + MySQL) using Docker, GitLab CI/CD, and Ansible.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      DEVELOPER MACHINE                           │
│                                                                  │
│   ┌──────────┐        ┌─────────────────────────┐               │
│   │  GitHub   │        │  GitLab CE (Docker)      │               │
│   │  (remote  │        │  http://localhost:8080    │               │
│   │   repo)   │        │  CI/CD server only        │               │
│   └──────────┘        │  (no runner here)         │               │
│                        └────────────┬─────────────┘               │
│                                     │                             │
└─────────────────────────────────────┼─────────────────────────────┘
                                      │  Runner polls for jobs
                                      │  (http://192.168.56.1:8080)
                                      │
┌─────────────────────────────────────┼─────────────────────────────┐
│                UBUNTU VM (192.168.56.10)                          │
│                                     │                             │
│   ┌─────────────────────────────────┼───────────────────────┐    │
│   │  GitLab Runner (shell executor) │                       │    │
│   │  Picks up jobs → runs docker compose directly           │    │
│   └─────────────────────────────────┼───────────────────────┘    │
│                                     │                             │
│   ┌─────────────────────────────────▼───────────────────────┐    │
│   │              Docker Compose Stack                        │    │
│   │                                                          │    │
│   │  ┌───────────┐   ┌──────────┐   ┌───────────┐          │    │
│   │  │  Nginx    │   │ Spring   │   │  MySQL 8  │          │    │
│   │  │ (Angular) ├──►│  Boot    ├──►│           │          │    │
│   │  │ Port 8000 │   │ Port 8090│   │ Port 3306 │          │    │
│   │  └───────────┘   └──────────┘   └───────────┘          │    │
│   └──────────────────────────────────────────────────────────┘    │
│                                                                   │
│   ┌──────────────┐   ┌──────────┐   ┌────────────────────┐      │
│   │ Node Exporter│   │   UFW    │   │ SSHD               │      │
│   │ Port 9100    │   │ Firewall │   │ Port 222           │      │
│   └──────────────┘   └──────────┘   └────────────────────┘      │
└──────────────────────────────────────────────────────────────────┘
```

**Key insight**: The GitLab Runner lives **on the VM**, not alongside GitLab. This means CI/CD jobs run directly on the deployment target — no SSH tunneling needed. Push triggers the runner, the runner runs `docker compose up` right where the app needs to run.

## Project Structure

```
.
├── README.md                              # This file
├── docs/
│   ├── SETUP_GUIDE.md                     # Detailed step-by-step guide
│   └── ARCHITECTURE.md                    # Architecture & data flow diagrams
│
├── Vagrantfile                            # VM provisioning (Ubuntu 20.04)
│
├── gitlab/                                # GitLab server setup
│   └── docker-compose.yml                 # GitLab CE only (runner is on VM)
│
├── ansible/                               # VM configuration
│   ├── ansible.cfg                        # Ansible configuration
│   ├── inventory/
│   │   └── hosts.yml                      # VM inventory
│   ├── playbook.yml                       # Main playbook
│   └── roles/
│       ├── docker/tasks/main.yml          # Install Docker & Compose
│       ├── node_exporter/tasks/main.yml   # Install Node Exporter
│       ├── ufw/tasks/main.yml             # Configure firewall
│       ├── sshd/                          # SSH port configuration
│       │   ├── tasks/main.yml
│       │   ├── handlers/main.yml
│       │   └── templates/sshd_config.j2
│       └── gitlab_runner/tasks/main.yml   # Install & register runner (shell executor)
│
├── .gitlab-ci.yml                         # CI/CD pipeline (runs on VM runner)
├── scripts/
│   └── deploy.sh                          # Manual deployment script (via SSH)
├── .gitignore
│
└── ecommerce-app/                         # Dockerized E-Commerce Application
    ├── docker/
    │   ├── backend/Dockerfile             # Spring Boot (multi-stage build)
    │   ├── frontend/
    │   │   ├── Dockerfile                 # Angular + Nginx (multi-stage build)
    │   │   └── nginx.conf                 # Nginx: SPA routing + API proxy
    │   └── db/
    │       ├── Dockerfile                 # MySQL 8 with init scripts
    │       └── init/
    │           └── 01-create-user.sql     # Modified DB user (Docker-compatible)
    ├── docker-compose.yml                 # Application stack (3 services)
    ├── .env.example                       # Environment variables template
    ├── backend/                           # (Cloned) Spring Boot application
    │   ├── spring-boot-ecommerce/
    │   └── sql-resources/
    └── frontend/                          # (Cloned) Angular application
        └── angular-ecommerce/
```

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) & Docker Compose (V2)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- [Vagrant](https://www.vagrantup.com/downloads)
- Ansible is installed automatically inside the VM by Vagrant (no host install needed)
- [Git](https://git-scm.com/downloads)

## Quick Start

### 1. Clone and Prepare

```bash
git clone https://github.com/<your-username>/egzakta-ecommerce-project.git
cd egzakta-ecommerce-project
cp ecommerce-app/.env.example ecommerce-app/.env
```

### 2. Run Locally with Docker Compose (Quick Test)

```bash
cd ecommerce-app/
docker compose up -d --build
# Wait ~30 seconds, then open http://localhost:8000
```

### 3. Full Setup (GitLab + VM + CI/CD)

See [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) for the complete walkthrough.

---

## Credentials & API Keys

| Service          | Username       | Password         | Notes                      |
|------------------|----------------|------------------|----------------------------|
| MySQL (root)     | `root`         | `root`           | Docker only                |
| MySQL (app)      | `ecommerceapp` | `ecommerceapp`   | Application user           |
| GitLab (initial) | `root`         | *auto-generated* | See setup guide            |

> **No external API keys are required.** All services run locally.

---

## Docker — Design Decisions

### Dockerfiles (Multi-Stage Builds)

All Dockerfiles are in `ecommerce-app/docker/` and use [multi-stage builds](https://docs.docker.com/build/building/multi-stage/):

| Dockerfile | Build Stage | Runtime Stage | Final Size |
|------------|-------------|---------------|------------|
| Backend    | `maven:3.9-eclipse-temurin-8` | `eclipse-temurin:8-jre-alpine` | ~150MB |
| Frontend   | `node:14-alpine` | `nginx:1.24-alpine` | ~30MB |
| Database   | — | `mysql:8.0` | ~550MB |

**Why multi-stage**: Build tools are discarded after compilation. Final image is 70-80% smaller.

### API Proxy — Solving Hardcoded URLs

The Angular app has hardcoded `http://localhost:8090/api` URLs. Nginx reverse-proxies `/api` to the backend container:

```
Browser → http://localhost:8000/api/products
            ↓
Nginx → http://backend:8090/api/products → Spring Boot → MySQL → response
```

See `ecommerce-app/docker/frontend/nginx.conf`.

### Docker Compose Services

| Service    | Int. Port | Ext. Port | Why |
|------------|-----------|-----------|-----|
| `db`       | 3306      | 3306      | MySQL default |
| `backend`  | 8090      | 8090      | Set in application.properties |
| `frontend` | 80        | **8000**  | Task requirement |

---

## Ansible — Design Decisions

### Role Execution Order

```
docker → node_exporter → sshd → ufw → gitlab_runner
```

**Why this order**: SSHD changes port to 222 **before** UFW blocks port 22. Reversing this would lock you out.

### Roles

| Role             | What It Does                                              |
|------------------|-----------------------------------------------------------|
| `docker`         | Installs Docker CE + Compose from official repo           |
| `node_exporter`  | Binary install + systemd service on port 9100             |
| `sshd`           | Changes SSH port 22 → 222                                 |
| `ufw`            | Firewall: allow 222, 8000, 9100                           |
| `gitlab_runner`  | Installs runner with **shell executor** + registers it    |

### Why Shell Executor

The runner uses `--executor "shell"` instead of `--executor "docker"`:
- Jobs run directly on the VM as the `gitlab-runner` user
- `docker compose` works natively against the host Docker daemon
- No nested Docker containers, no socket mounts, no complexity
- Docker build cache persists between jobs (faster builds)

### Usage

Ansible runs inside the VM via Vagrant's `ansible_local` provisioner — no host Ansible install or WSL needed.

```bash
# From the project root (PowerShell or any terminal)
vagrant provision

# Register the runner (after getting token from GitLab UI)
vagrant provision --provision-with ansible_local -- --tags gitlab_runner \
  -e "gitlab_runner_token=YOUR_TOKEN"
```

---

## GitLab Setup

GitLab CE runs on your developer machine as a Docker container. The runner lives on the VM.

```bash
cd gitlab/
docker compose up -d

# Wait 3-5 minutes, then get root password:
docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password

# Open http://localhost:8080 — login as root
```

---

## CI/CD Pipeline

### Pipeline Flow

```
git push → GitLab assigns job → Runner on VM picks it up
         → Runner clones repo → cd ecommerce-app/
         → docker compose build → docker compose up -d
         → App live on port 8000
```

**No SSH, no CI/CD variables needed.** The runner is already on the VM.

### Pipeline Stages

1. **Build**: Runs `docker compose build` to validate all images compile
2. **Deploy**: Runs `docker compose up -d` to start the application

---

## Troubleshooting

### Frontend shows blank page or API errors
Nginx proxies `/api` → `backend:8090/api`. Port 8090 is also exposed directly.

### MySQL initialization fails
```bash
cd ecommerce-app/
docker compose down -v && docker compose up -d --build
```

### Can't SSH after port change
```bash
ssh -p 222 vagrant@192.168.56.10
```

### GitLab is slow / uses too much RAM
GitLab CE requires 4+ GB RAM. Ensure your host has at least 8GB total.

### Runner can't reach GitLab
The VM accesses GitLab at `http://192.168.56.1:8080` (host IP on VirtualBox network). Verify connectivity: `curl http://192.168.56.1:8080` from the VM.

---

## E-Commerce Application Source

Cloned from [abhinav-nath/full-stack-ecommerce-project](https://github.com/abhinav-nath/full-stack-ecommerce-project):
- **Frontend**: Angular 9 with Bootstrap 4
- **Backend**: Spring Boot 2.2.7 with Spring Data REST (Java 8)
- **Database**: MySQL 8 with 100 sample products

## License

This project is for interview/demonstration purposes.
