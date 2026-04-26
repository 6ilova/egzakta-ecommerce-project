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
vagrant ssh       # Test SSH access
exit
```

The VM will be available at `192.168.56.10`.

---

## 3. Start GitLab Locally

GitLab runs as a Docker container on your host machine (not the VM).

```bash
cd gitlab/
docker compose up -d

# Wait 3-5 minutes for GitLab to initialize:
docker logs -f gitlab
# Wait until you see "gitlab Reconfigured!" — then Ctrl+C
```

### Get the initial root password

```bash
docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

**Save this password** — it's deleted after 24 hours.

### Access GitLab

- **URL**: http://localhost:8080
- **Username**: `root`
- **Password**: *(from command above)*

---

## 4. Create a GitLab Project

1. Log into GitLab at http://localhost:8080
2. Click **"New Project"** → **"Create blank project"**
3. **Name**: `ecommerce-project`
4. Uncheck "Initialize repository with a README"
5. Click **"Create project"**

### Add GitLab as a remote

```bash
cd ..   # Back to project root

git remote add gitlab http://192.168.56.1:8080/root/ecommerce-project.git

git push gitlab main
# Enter: root / <your-password>
```

---

## 5. Configure the VM with Ansible

Ansible runs **inside the VM** via Vagrant's `ansible_local` provisioner — no host Ansible install or WSL needed.

```bash
# From the project root
vagrant provision
```

This takes 5-10 minutes and configures:
- ✅ Docker CE + Docker Compose
- ✅ Node Exporter (port 9100)
- ✅ SSH port changed from 22 → 222
- ✅ UFW firewall (allow 222, 8000, 9100)
- ✅ GitLab Runner installed (not yet registered)

### Verify

```bash
vagrant ssh

docker --version          # Docker installed
sudo ufw status           # Firewall active
curl localhost:9100/metrics | head -5   # Node Exporter running
sudo ss -tlnp | grep sshd              # SSH on port 222

exit
```

---

## 6. Register the GitLab Runner

### Get the Registration Token

1. In GitLab: **Admin Area** (wrench icon) → **CI/CD** → **Runners**
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
> ansible-playbook playbook.yml -i inventory/hosts.yml --tags gitlab_runner -e "gitlab_runner_token=YOUR_TOKEN_HERE"
> ```

### Verify

Go to GitLab → **Admin Area** → **CI/CD** → **Runners** — the runner should show as **online** (green dot).

You can also verify on the VM:
```bash
vagrant ssh -c "sudo gitlab-runner list"
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

**No SSH keys or CI/CD variables needed** — the runner is already on the VM.

### Monitor

GitLab → your project → **CI/CD** → **Pipelines**

First deployment takes 10-15 minutes (downloading Docker images, compiling source).

---

## 8. Verify Everything Works

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
| API Endpoint     | http://192.168.56.10:8000/api/products       |
| Node Exporter    | http://192.168.56.10:9100/metrics            |
| GitLab           | http://localhost:8080                         |
| SSH to VM        | `ssh -p 222 vagrant@192.168.56.10`           |
| Manual deploy    | `./scripts/deploy.sh 192.168.56.10`          |

---

## Local Testing (Without VM)

```bash
cd ecommerce-app/
cp .env.example .env
docker compose up -d --build
# Open http://localhost:8000
```
