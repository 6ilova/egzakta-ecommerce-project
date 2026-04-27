# DevOps Engineer — E-Commerce Project

A complete DevOps solution for deploying a full-stack e-commerce application (Angular + Spring Boot + MySQL) using Docker, GitLab CI/CD, and Ansible.

## Architecture

![arch](docs/img/arch.png)


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

## Quick Reference

| Component        | URL / Command                               |
|------------------|---------------------------------------------|
| E-Commerce App   | http://192.168.56.10:8000                    |
| Grafana (PLG)    | http://192.168.56.10:8000/grafana/           |
| API Endpoint     | http://192.168.56.10:8000/api/products       |
| Node Exporter    | http://192.168.56.10:9100/metrics            |
| GitLab           | http://localhost:8080                         |
| SSH to VM        | `ssh -p 222 vagrant@192.168.56.10`           |
| Manual deploy    | `./scripts/deploy.sh 192.168.56.10`          |

---

## E-Commerce Application Source

Cloned from [abhinav-nath/full-stack-ecommerce-project](https://github.com/abhinav-nath/full-stack-ecommerce-project):
- **Frontend**: Angular 9 with Bootstrap 4
- **Backend**: Spring Boot 2.2.7 with Spring Data REST (Java 8)
- **Database**: MySQL 8 with 100 sample products

## License

This project is for interview/demonstration purposes.
