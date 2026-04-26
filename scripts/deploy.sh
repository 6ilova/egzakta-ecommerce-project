#!/bin/bash
# ============================================
# Manual Deployment Script
# ============================================
#
# WHAT THIS DOES:
#   Deploys the e-commerce application to the target VM via SSH.
#   This is the same logic used by the GitLab CI deploy stage,
#   but can be run manually from your development machine.
#
# USAGE:
#   ./scripts/deploy.sh <VM_HOST> [VM_USER] [SSH_PORT]
#
# EXAMPLES:
#   ./scripts/deploy.sh 192.168.56.10                    # defaults: vagrant, 222
#   ./scripts/deploy.sh 192.168.56.10 ubuntu 222         # custom user
#   ./scripts/deploy.sh production.example.com deploy 222 # remote server
#
# PREREQUISITES:
#   - SSH key-based access to the VM
#   - Docker and Docker Compose installed on the VM (via Ansible)
#   - Git installed on the VM
# ============================================

set -euo pipefail
# set -e: Exit on any error
# set -u: Treat undefined variables as errors
# set -o pipefail: Catch errors in piped commands

VM_HOST="${1:?Usage: $0 <VM_HOST> [VM_USER] [SSH_PORT]}"
VM_USER="${2:-vagrant}"
SSH_PORT="${3:-222}"
APP_DIR="/opt/ecommerce"
REPO_URL="${4:-$(git remote get-url origin 2>/dev/null || echo '')}"

echo "============================================"
echo "Deploying E-Commerce Application"
echo "============================================"
echo "Target: ${VM_USER}@${VM_HOST}:${SSH_PORT}"
echo "App Dir: ${APP_DIR}"
echo "============================================"

# Deploy to the VM via SSH heredoc
ssh -o StrictHostKeyChecking=no -p "${SSH_PORT}" "${VM_USER}@${VM_HOST}" << DEPLOY_SCRIPT
set -e

echo "[1/5] Setting up application directory..."
sudo mkdir -p ${APP_DIR}
sudo chown \$(whoami):\$(whoami) ${APP_DIR}
cd ${APP_DIR}

echo "[2/5] Syncing code..."
if [ -d ".git" ]; then
    git pull origin main || git pull origin master || true
else
    if [ -n "${REPO_URL}" ]; then
        git clone ${REPO_URL} . || true
    else
        echo "ERROR: No git repository found and no REPO_URL provided"
        exit 1
    fi
fi

# Move into the ecommerce-app subdirectory where docker-compose.yml lives
cd ${APP_DIR}/ecommerce-app

echo "[3/5] Setting up environment..."
if [ ! -f .env ]; then
    cp .env.example .env
fi

echo "[4/5] Building and starting containers..."
docker compose down --remove-orphans 2>/dev/null || true
docker compose build
docker compose up -d

echo "[5/5] Verifying deployment..."
sleep 20
docker compose ps

echo ""
echo "============================================"
echo "Deployment completed!"
echo "Application: http://${VM_HOST}:8000"
echo "Node Exporter: http://${VM_HOST}:9100"
echo "============================================"
DEPLOY_SCRIPT
