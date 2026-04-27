# Setup Guide — Step by Step

This guide walks you through the complete setup from scratch.

## Table of Contents

1. [Clone the Repository](#1-clone-the-repository)
2. [Start the Ubuntu VM](#2-start-the-ubuntu-vm)
3. [Start GitLab Locally](#3-start-gitlab-locally)
4. [Create a GitLab Project](#4-create-a-gitlab-project)
5. [Configure the VM with Ansible](#5-configure-the-vm-with-ansible)
6. [Register the GitLab Runner](#6-register-the-gitlab-runner)
7. [Push and Trigger Deployment](#7-push-and-trigger-deployment)
8. [Verify Everything Works](#8-verify-everything-works)

---

## 1. Clone the Repository

```bash
git clone https://github.com/<your-username>/egzakta-ecommerce-project.git
cd egzakta-ecommerce-project
```

The e-commerce application source is already in `ecommerce-app/backend/` and `ecommerce-app/frontend/`.

---

## 2. Start the Ubuntu VM

```bash
vagrant up        # Takes 5-10 minutes on first run
vagrant status    # Verify VM is running
```

The VM will be available at `192.168.56.10`.

---

## 3. Configure the VM with Ansible

Ansible runs **inside the VM** via Vagrant's `ansible_local` provisioner

```bash
# From the project root
vagrant provision
```

This takes 5-10 minutes and configures:
- Docker CE + Docker Compose
- Node Exporter (port 9100)
- SSH port changed from 22 → 222
- FW firewall (allow 222, 8000, 9100)
- GitLab Runner installed (not yet registered)

Verify:

```bash
ssh -p 222 vagrant@192.168.56.10

docker --version          # Docker installed
sudo ufw status           # Firewall active
curl localhost:9100/metrics | head -5   # Node Exporter running
sudo ss -tlnp | grep sshd              # SSH on port 222

exit
```
---

## 4. Start GitLab Locally

GitLab runs as a Docker container on host machine.

```bash
cd gitlab/
docker compose up -d
docker logs -f gitlab
# Wait for "gitlab Reconfigured!"
```

### Get the initial root password

```bash
docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```
Save this password

### Access GitLab

- **URL**: http://localhost:8080
- **Username**: `root`
- **Password**: *(from command above)*

---

## 5. Create a GitLab Project

1. Log into GitLab at http://localhost:8080
2. Click **"New Project"** → **"Create blank project"**
3. **Name**: `ecommerce-project`
4. Uncheck "Initialize repository with a README"
5. Click **"Create project"**

### Add GitLab as a remote

```bash
# In project root

git remote add gitlab http://192.168.56.1:8080/root/ecommerce-project.git

git push gitlab main
```

---

## 6. Register the GitLab Runner

### Get the Registration Token

1. In GitLab: **Admin Area** → **CI/CD** → **Runners**
2. Click **"Register an instance runner"**
3. Copy the registration token

### Register via Vagrant

```bash
# From the project root
vagrant provision
```

> **Note**: If you only want to re-run the runner registration role, you can SSH into the VM and run Ansible directly:
> ```bash
> vagrant ssh
> cd /vagrant/ansible
> ansible-playbook playbook.yml -i inventory/hosts.yml --tags gitlab_runner -e "gitlab_runner_token==YOUR_TOKEN_HERE"
> ```

### Verify

Go to GitLab → **Admin Area** → **CI/CD** → **Runners** — the runner should show as **online**.

Verify on the VM:
```bash
ssh -p 222 vagrant@192.168.56.10 -c "sudo gitlab-runner list"
```

---

## 7. Push and Trigger Deployment

```bash
git add .
git commit -m "Initial deployment"
git push gitlab main
```

The pipeline will:
1. **Build**: Runner on VM runs `docker compose build`
2. **Deploy**: Runner on VM runs `docker compose up -d`


---

## 8. Verify Everything is Working

### Application (Port 8000)

Open: **http://192.168.56.10:8000**

```bash
curl -s http://192.168.56.10:8000/api/products | head -20
```

### Node Exporter (Port 9100)

```bash
curl -s http://192.168.56.10:9100/metrics | head -5
```

### SSH (Port 222)

```bash
ssh -p 222 vagrant@192.168.56.10
```

### Docker containers

```bash
ssh -p 222 vagrant@192.168.56.10 "docker ps"
```

### UFW firewall

```bash
ssh -p 222 vagrant@192.168.56.10 "sudo ufw status numbered"
```

Expected:
```
     To                         Action      From
     --                         ------      ----
[ 1] 222/tcp                    ALLOW IN    Anywhere
[ 2] 8000/tcp                   ALLOW IN    Anywhere
[ 3] 9100/tcp                   ALLOW IN    Anywhere
```

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
