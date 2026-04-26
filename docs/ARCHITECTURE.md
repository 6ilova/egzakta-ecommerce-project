# Architecture & Data Flow

This document explains the complete system architecture, how every component interacts, and what happens at each stage — from initial setup to a production deployment triggered by a `git push`.

---

## System Overview

There are **two machines** involved:

| Machine | Role | What Runs On It |
|---------|------|-----------------|
| **Developer Machine** (your laptop/desktop) | Development, GitLab hosting, Ansible control | GitLab CE, GitLab Runner, Vagrant, Ansible |
| **Ubuntu VM** (VirtualBox, managed by Vagrant) | Production target | Docker, E-Commerce App, Node Exporter, UFW, SSHD |

```
┌──────────────────────────────────────────────────────────────────────┐
│                      DEVELOPER MACHINE                               │
│                                                                      │
│   ┌──────────┐   ┌───────────────────────────────┐   ┌───────────┐  │
│   │  GitHub   │   │     GitLab CE (Docker)        │   │  Ansible  │  │
│   │  (remote  │   │     http://localhost:8080      │   │  Control  │  │
│   │   repo)   │   │  ┌─────────────────────────┐  │   │  Node     │  │
│   └──────────┘   │  │  GitLab Runner (Docker)  │  │   └─────┬─────┘  │
│                   │  │  Polls for CI/CD jobs    │  │         │        │
│                   │  └────────────┬────────────┘  │         │        │
│                   └───────────────┼───────────────┘         │        │
│                                   │                         │        │
└───────────────────────────────────┼─────────────────────────┼────────┘
                                    │ SSH (port 222)          │ SSH (port 22→222)
                                    │ Deploy commands         │ Ansible playbook
                                    ▼                         ▼
┌──────────────────────────────────────────────────────────────────────┐
│                      UBUNTU VM (192.168.56.10)                       │
│                                                                      │
│   ┌────────────────────────────────────────────────────────────┐     │
│   │              Docker Compose Stack (port 8000)              │     │
│   │                                                            │     │
│   │   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐ │     │
│   │   │    Nginx      │   │  Spring Boot  │   │   MySQL 8    │ │     │
│   │   │   (Angular)   │──▶│   (REST API)  │──▶│  (Database)  │ │     │
│   │   │  Port 80/8000 │   │  Port 8090    │   │  Port 3306   │ │     │
│   │   └──────────────┘   └──────────────┘   └──────────────┘ │     │
│   └────────────────────────────────────────────────────────────┘     │
│                                                                      │
│   ┌──────────────┐    ┌──────────────┐    ┌────────────────────┐    │
│   │ Node Exporter │    │     UFW       │    │   SSHD Service     │    │
│   │  Port 9100    │    │   Firewall    │    │   Port 222         │    │
│   │  (metrics)    │    │ 222,8000,9100 │    │   (custom port)    │    │
│   └──────────────┘    └──────────────┘    └────────────────────┘    │
│                                                                      │
│   ┌──────────────┐                                                   │
│   │GitLab Runner │                                                   │
│   │ (on the VM)  │                                                   │
│   └──────────────┘                                                   │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Infrastructure Setup

### What happens when you run `vagrant up`

```
Developer Machine                          VirtualBox
      │                                        │
      │  1. vagrant up                         │
      ├───────────────────────────────────────▶│
      │  2. Download ubuntu/focal64 box        │
      │     (only on first run, ~500MB)        │
      │◀───────────────────────────────────────┤
      │  3. Create VM:                         │
      │     - 4GB RAM, 2 CPUs                  │
      │     - Private network: 192.168.56.10   │
      │     - Port forwards: 222→2222,         │
      │       8000→8000, 9100→9100             │
      ├───────────────────────────────────────▶│
      │  4. Run shell provisioner:             │
      │     apt install python3 python3-pip    │
      │◀───────────────────────────────────────┤
      │  5. VM ready, SSH key generated        │
      │                                        │
```

**Result**: A bare Ubuntu 20.04 VM at `192.168.56.10`, accessible via `vagrant ssh` on port 22. Python 3 is installed (required by Ansible). Nothing else is configured yet.

### What happens when you run `ansible-playbook playbook.yml`

Ansible connects to the VM via SSH and executes 5 roles in order:

```
Ansible (Developer Machine)                Ubuntu VM (192.168.56.10)
      │                                          │
      │  SSH connect (port 22)                   │
      ├─────────────────────────────────────────▶│
      │                                          │
      │  ┌─ ROLE 1: docker ──────────────────────┤
      │  │  • apt install prerequisites          │
      │  │  • Add Docker GPG key + repo          │
      │  │  • apt install docker-ce, compose      │
      │  │  • Add vagrant user to docker group    │
      │  │  • systemctl enable docker             │
      │  │  • pip install docker (Python SDK)      │
      │  └───────────────────────────────────────┤
      │                                          │
      │  ┌─ ROLE 2: node_exporter ───────────────┤
      │  │  • Create system user 'node_exporter' │
      │  │  • Download binary from GitHub         │
      │  │  • Install to /usr/local/bin/          │
      │  │  • Create systemd service file         │
      │  │  • systemctl enable node_exporter      │
      │  │  • Clean up /tmp downloads             │
      │  └───────────────────────────────────────┤
      │                                          │
      │  ┌─ ROLE 3: sshd ───────────────────────┤
      │  │  • Template sshd_config (Port 222)    │
      │  │  • Validate config (sshd -t)          │
      │  │  • Restart sshd → NOW ON PORT 222     │
      │  └───────────────────────────────────────┤
      │                                          │
      │  ┌─ ROLE 4: ufw ────────────────────────┤
      │  │  • apt install ufw                    │
      │  │  • Default: deny incoming             │
      │  │  • Allow: 222 (SSH)                   │
      │  │  • Allow: 8000 (App)                  │
      │  │  • Allow: 9100 (Node Exporter)        │
      │  │  • Temp allow: 22 (safety net)        │
      │  │  • Enable UFW                         │
      │  │  • Remove temp port 22 rule           │
      │  └───────────────────────────────────────┤
      │                                          │
      │  ┌─ ROLE 5: gitlab_runner ───────────────┤
      │  │  • Add GitLab Runner GPG key + repo   │
      │  │  • apt install gitlab-runner          │
      │  │  • Register (only if token provided)  │
      │  │  • systemctl enable gitlab-runner      │
      │  └───────────────────────────────────────┤
      │                                          │
```

**Why this order matters (critical)**:

```
WRONG ORDER (would lock you out):
  ufw (blocks port 22) → sshd (tries to change to 222) → 💀 LOCKED OUT

CORRECT ORDER (what we do):
  sshd (SSH moves to 222) → ufw (blocks 22, allows 222) → ✅ SAFE
```

**Result**: The VM now has Docker, Node Exporter on port 9100, SSH on port 222, firewall blocking everything except 222/8000/9100, and GitLab Runner installed.

---

## Phase 2: GitLab Setup

### What happens when you start GitLab

```
Developer Machine
      │
      │  cd gitlab/ && docker compose up -d
      │
      ▼
┌─────────────────────────────────────────────────────┐
│  Docker on Developer Machine                        │
│                                                     │
│  ┌──────────────────────────────────────────────┐  │
│  │  GitLab CE Container                         │  │
│  │  • Initializes PostgreSQL database           │  │
│  │  • Generates root password                   │  │
│  │  • Starts Puma web server (port 8080)        │  │
│  │  • Starts Sidekiq (background jobs)          │  │
│  │  • Starts Container Registry (port 5050)     │  │
│  │  • Takes 3-5 minutes to fully start          │  │
│  └──────────────────────────────────────────────┘  │
│                        │                            │
│                        │ Docker network             │
│                        ▼                            │
│  ┌──────────────────────────────────────────────┐  │
│  │  GitLab Runner Container                     │  │
│  │  • Waits for registration                    │  │
│  │  • After registration: polls GitLab for jobs │  │
│  │  • Docker socket mounted from host           │  │
│  └──────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Runner Registration Flow

```
You (Browser)              GitLab UI                  Runner Container
     │                        │                             │
     │  1. Open Admin Area    │                             │
     │  → CI/CD → Runners     │                             │
     ├───────────────────────▶│                             │
     │  2. Copy reg. token    │                             │
     │◀───────────────────────┤                             │
     │                        │                             │
     │  3. Run: ./register-runner.sh TOKEN                  │
     ├─────────────────────────────────────────────────────▶│
     │                        │  4. Runner sends token      │
     │                        │◀────────────────────────────┤
     │                        │  5. GitLab validates token  │
     │                        │  6. Returns runner config   │
     │                        ├────────────────────────────▶│
     │                        │  7. Runner starts polling   │
     │                        │◀────────────────────────────┤
     │                        │     "Any jobs for me?"      │
     │                        │     (every 3 seconds)       │
```

---

## Phase 3: Application Architecture (Docker Compose)

### The Three Services

```
                    Internet / Browser
                          │
                          │ http://192.168.56.10:8000
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    Docker Compose Network                     │
│                   (ecommerce-network)                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              FRONTEND (Nginx + Angular)              │   │
│  │              Container: ecommerce-frontend           │   │
│  │              Port: 8000 → 80                         │   │
│  │                                                      │   │
│  │  Nginx does TWO things:                              │   │
│  │                                                      │   │
│  │  1. Serves Angular static files (HTML/CSS/JS)        │   │
│  │     GET /              → /usr/share/nginx/html/      │   │
│  │     GET /products      → /usr/share/nginx/html/      │   │
│  │     GET /main.js       → /usr/share/nginx/html/      │   │
│  │     (All routes → index.html for SPA client routing) │   │
│  │                                                      │   │
│  │  2. Reverse proxy API calls to backend               │   │
│  │     GET /api/products  → http://backend:8090/api/... │   │
│  │     GET /api/product-category → backend:8090/api/... │   │
│  └───────────────────────┬──────────────────────────────┘   │
│                          │                                   │
│                          │ /api/* requests                   │
│                          ▼                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              BACKEND (Spring Boot)                   │   │
│  │              Container: ecommerce-backend            │   │
│  │              Port: 8090                              │   │
│  │                                                      │   │
│  │  Spring Data REST auto-generates these endpoints:    │   │
│  │    GET /api/products           → list all products   │   │
│  │    GET /api/products/{id}      → single product      │   │
│  │    GET /api/products/search/findByCategoryId?id=N    │   │
│  │    GET /api/products/search/findByNameContaining?... │   │
│  │    GET /api/product-category   → list categories     │   │
│  │                                                      │   │
│  │  Spring Boot auto-configures:                        │   │
│  │    • JPA/Hibernate for ORM                           │   │
│  │    • MySQL connection via JDBC                       │   │
│  │    • REST endpoints via Spring Data REST             │   │
│  └───────────────────────┬──────────────────────────────┘   │
│                          │                                   │
│                          │ JDBC: mysql://db:3306/...         │
│                          ▼                                   │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              DATABASE (MySQL 8.0)                    │   │
│  │              Container: ecommerce-db                 │   │
│  │              Port: 3306                              │   │
│  │                                                      │   │
│  │  On first startup (empty volume):                    │   │
│  │    1. Creates database: full-stack-ecommerce         │   │
│  │    2. Runs 01-create-user.sql:                       │   │
│  │       CREATE USER 'ecommerceapp'@'%'                 │   │
│  │    3. Runs 02-create-products.sql:                   │   │
│  │       Creates tables: product, product_category      │   │
│  │       Inserts 100 sample products in 5 categories    │   │
│  │                                                      │   │
│  │  Data stored in Docker volume: mysql-data            │   │
│  │  (persists across container restarts)                │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Startup Sequence (Dependency Chain)

```
Time ──────────────────────────────────────────────────────────▶

MySQL (db)     ████████████████████████████████████████████████
               │ Start │ Init DB │ Ready (healthcheck passes) │
               0s      10s       30s

Backend        ░░░░░░░░░░░░░░░░░░████████████████████████████
               │ Waiting...     │ Start │ Connect DB │ Ready │
               (depends_on:     30s     33s          35s
                service_healthy)

Frontend       ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░█████████████
               │ Waiting...                      │ Start │ OK │
               (depends_on: backend)             35s     36s
```

**Why healthcheck matters**: Without `depends_on: condition: service_healthy`, Docker would start the backend immediately after MySQL's container starts — but MySQL takes 15-30 seconds to initialize its database. The backend would crash with "Connection refused" and exit. The healthcheck (`mysqladmin ping`) ensures MySQL is actually accepting connections before the backend starts.

### The API Proxy Problem & Solution

The Angular source code has **hardcoded** API URLs:

```typescript
// frontend/angular-ecommerce/src/app/services/product.service.ts
private baseUrl = "http://localhost:8090/api/products";
private categoryUrl = "http://localhost:8090/api/product-category";
```

In Docker, `localhost` inside the browser means the user's machine, not the backend container. The backend is in a separate container with its own IP.

**Solution — Nginx reverse proxy**:

```
WITHOUT PROXY (broken):
  Browser → http://localhost:8090/api/products
                    ↓
  Nothing listening on host port 8090 (or wrong container) → ❌ ERROR

WITH PROXY (our solution):
  Browser loads Angular from → http://localhost:8000
  Angular calls → http://localhost:8090/api/products
                         ↓
  Port 8090 IS exposed in docker-compose, so this actually works too!
  
  BUT for production (VM deployment), we also have:
  Nginx catches /api/* → proxy_pass http://backend:8090/api
  "backend" resolves via Docker DNS → 172.18.0.3 (backend container IP)
```

We expose port 8090 in docker-compose **and** set up the Nginx proxy — belt and suspenders. The Angular app's hardcoded `localhost:8090` works because we forward that port, and the `/api` proxy works as an additional path.

---

## Phase 4: CI/CD Pipeline

### What happens on `git push`

```
Developer              GitLab               Runner              Ubuntu VM
   │                      │                    │                    │
   │  git push gitlab     │                    │                    │
   │  main                │                    │                    │
   ├─────────────────────▶│                    │                    │
   │                      │                    │                    │
   │                      │  Detect .gitlab-ci.yml                 │
   │                      │  Create pipeline   │                    │
   │                      │                    │                    │
   │                      │  ── BUILD STAGE ─────────────────────  │
   │                      │  Assign job        │                    │
   │                      ├───────────────────▶│                    │
   │                      │                    │                    │
   │                      │  Runner executes:  │                    │
   │                      │  docker compose    │                    │
   │                      │  build --no-cache  │                    │
   │                      │                    │                    │
   │                      │  Job result: ✅     │                    │
   │                      │◀───────────────────┤                    │
   │                      │                    │                    │
   │                      │  ── DEPLOY STAGE ────────────────────  │
   │                      │  Assign job        │                    │
   │                      ├───────────────────▶│                    │
   │                      │                    │                    │
   │                      │                    │  SSH (port 222)    │
   │                      │                    ├───────────────────▶│
   │                      │                    │                    │
   │                      │                    │  1. mkdir /opt/    │
   │                      │                    │     ecommerce      │
   │                      │                    │                    │
   │                      │                    │  2. git pull       │
   │                      │                    │     (latest code)  │
   │                      │                    │                    │
   │                      │                    │  3. cp .env.example│
   │                      │                    │     .env           │
   │                      │                    │                    │
   │                      │                    │  4. docker compose │
   │                      │                    │     down           │
   │                      │                    │                    │
   │                      │                    │  5. docker compose │
   │                      │                    │     build          │
   │                      │                    │                    │
   │                      │                    │  6. docker compose │
   │                      │                    │     up -d          │
   │                      │                    │                    │
   │                      │                    │  7. Verify:        │
   │                      │                    │     docker compose │
   │                      │                    │     ps             │
   │                      │                    │◀───────────────────┤
   │                      │                    │                    │
   │                      │  Job result: ✅     │                    │
   │                      │◀───────────────────┤                    │
   │                      │                    │                    │
   │  Pipeline: ✅ passed  │                    │                    │
   │◀─────────────────────┤                    │                    │
   │                      │                    │                    │
   │              App live at http://192.168.56.10:8000             │
```

---

## Phase 5: Request Lifecycle (User Visits the App)

What happens when a user opens `http://192.168.56.10:8000`:

```
Step 1: Browser → Nginx (port 8000)
        GET /
        Nginx serves index.html (Angular app)

Step 2: Browser downloads Angular JS bundles
        GET /main.abc123.js, /polyfills.def456.js, etc.
        Nginx serves static files from /usr/share/nginx/html/

Step 3: Angular app initializes in the browser
        Angular router renders the product list component
        Component calls ProductService.getProductCategories()

Step 4: Browser → Backend (port 8090)
        GET http://localhost:8090/api/product-category
        ┌─────────────────────────────────────────────────┐
        │  Spring Boot receives the request               │
        │  Spring Data REST auto-maps to JPA repository   │
        │  JPA/Hibernate generates SQL:                   │
        │    SELECT * FROM product_category               │
        │  MySQL executes query, returns 5 categories     │
        │  Spring serializes to JSON with HAL format      │
        └─────────────────────────────────────────────────┘
        Response: { _embedded: { productCategory: [...] } }

Step 5: Angular renders sidebar with 5 categories
        User clicks "Books" category

Step 6: Browser → Backend
        GET http://localhost:8090/api/products/search/findByCategoryId?id=1
        Backend queries MySQL, returns paginated products
        Response: { _embedded: { products: [...] }, page: { ... } }

Step 7: Angular renders product grid with book listings
```

---

## Network Topology

### Ports Summary

| Port | Service | Machine | Protocol | Access |
|------|---------|---------|----------|--------|
| 8000 | Nginx (Angular + proxy) | VM | HTTP | Public (UFW allows) |
| 8090 | Spring Boot API | VM | HTTP | Internal (Docker network) + exposed |
| 3306 | MySQL | VM | TCP | Internal (Docker network) + exposed |
| 9100 | Node Exporter | VM | HTTP | Public (UFW allows) |
| 222 | SSH | VM | TCP | Public (UFW allows) |
| 8080 | GitLab CE | Developer Machine | HTTP | Localhost only |
| 5050 | GitLab Registry | Developer Machine | HTTP | Localhost only |
| 2224 | GitLab SSH | Developer Machine | TCP | Localhost only |

### Docker Network Resolution

Inside the Docker Compose network, services find each other by name:

```
Container Name         DNS Name       IP (assigned by Docker)
ecommerce-frontend  →  frontend   →   172.18.0.4
ecommerce-backend   →  backend    →   172.18.0.3
ecommerce-db        →  db         →   172.18.0.2
```

When `nginx.conf` says `proxy_pass http://backend:8090`, Docker's internal DNS resolves `backend` to `172.18.0.3`. No hardcoded IPs needed.

---

## Security Layers

```
Internet
    │
    ▼
┌─────────┐
│   UFW   │  Firewall: only 222, 8000, 9100 allowed
│ (Layer 1)│  Everything else → DROPPED silently
└────┬────┘
     │
     ▼
┌─────────┐
│  SSHD   │  Port 222 (non-standard reduces bot scanning)
│ (Layer 2)│  Key-based auth enabled, root password login disabled
└────┬────┘
     │
     ▼
┌─────────┐
│ Docker  │  Containers isolated from host filesystem
│ (Layer 3)│  Inter-container communication via bridge network only
└────┬────┘
     │
     ▼
┌─────────┐
│  MySQL  │  User 'ecommerceapp' with app-specific password
│ (Layer 4)│  Root accessible only from within container
└─────────┘
```

---

## Complete Timeline: Zero to Running App

```
Time    Action                                    Result
─────   ─────────────────────────────────         ──────────────────────
 0:00   vagrant up                                VM created
 5:00   cd gitlab/ && docker compose up -d        GitLab starting...
 8:00   GitLab fully started                      http://localhost:8080
 9:00   Create project in GitLab UI               Project exists
10:00   cd ansible/ && ansible-playbook ...        VM configured
15:00   Copy runner token from GitLab UI          Token obtained
15:30   ./register-runner.sh TOKEN                Runner registered
16:00   Set CI/CD variables in GitLab UI          SSH credentials stored
17:00   git push gitlab main                      Pipeline triggers
17:01   Build stage starts                        Docker images building
22:00   Build stage completes                     Images ready
22:01   Deploy stage starts                       SSH into VM
22:30   docker compose build on VM                Building on VM
32:00   docker compose up -d on VM                Containers starting
32:30   MySQL initialized                         DB ready
33:00   Backend connected to MySQL                API ready
33:01   Frontend serving                          App ready
        ───────────────────────────────
33:01   http://192.168.56.10:8000                 🎉 E-COMMERCE APP LIVE
        http://192.168.56.10:9100/metrics         📊 METRICS AVAILABLE
        ssh -p 222 vagrant@192.168.56.10          🔐 SSH ACCESS ON 222
```
