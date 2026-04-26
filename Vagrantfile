# -*- mode: ruby -*-
# vi: set ft=ruby :
# ============================================
# Vagrantfile — Ubuntu VM for E-Commerce Application
# ============================================
#
# WHAT THIS DOES:
#   Provisions an Ubuntu 20.04 (Focal) VM using VirtualBox with:
#   - 4GB RAM, 2 CPUs (needed for Docker builds)
#   - Private network at 192.168.56.10 (accessible from host)
#   - Port forwarding for SSH (222), app (8000), and monitoring (9100)
#   - Python 3 pre-installed (required by Ansible)
#
# USAGE:
#   vagrant up          # Create and start the VM
#   vagrant ssh         # SSH into the VM (on default port 22)
#   vagrant halt        # Stop the VM
#   vagrant destroy     # Delete the VM completely
#
# WHY UBUNTU 20.04 (Focal):
#   - LTS release with long-term support
#   - Well-tested with Docker CE and Ansible
#   - Stable package repositories
#
# WHY 4GB RAM:
#   Docker image builds (especially Maven/Node) are memory-intensive.
#   With less than 3GB, builds may fail with OOM (Out of Memory) errors.
#
# NETWORKING:
#   The private_network IP (192.168.56.10) creates a host-only network.
#   The VM is accessible from your host machine at this IP, but not from
#   the broader network. This is ideal for development.
# ============================================

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.hostname = "ecommerce-vm"

  # ---- Network Configuration ----
  # Private network: VM accessible at 192.168.56.10 from the host
  config.vm.network "private_network", ip: "192.168.56.10"

  # Port forwarding: access VM services from localhost
  config.vm.network "forwarded_port", guest: 222,  host: 2222,  id: "ssh-custom"
  config.vm.network "forwarded_port", guest: 8000, host: 8000,  id: "app"
  config.vm.network "forwarded_port", guest: 9100, host: 9100,  id: "node-exporter"

  # ---- VM Resources ----
  config.vm.provider "virtualbox" do |vb|
    vb.name = "ecommerce-vm"
    vb.memory = "4096"
    vb.cpus = 2
  end

  # ---- Port Range ----
  config.vm.usable_port_range = 2200..2250

  # ---- Initial Provisioning ----
  # Install Python 3 (required by Ansible to run on the target)
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y python3 python3-pip
  SHELL

  # ---- Ansible Provisioner ----
  # Uses ansible_local to install Ansible INSIDE the VM and run the playbook
  # locally. This avoids WSL permission issues with SSH keys and ansible.cfg.
  # The /vagrant synced folder gives Ansible access to all project files.
  #
  # USAGE:
  #   vagrant provision          # Run all roles
  #   vagrant provision --provision-with ansible_local  # Run only Ansible
  config.vm.provision "ansible_local" do |ansible|
    ansible.playbook = "ansible/playbook.yml"
    ansible.provisioning_path = "/vagrant"
    ansible.inventory_path = "ansible/inventory/hosts.yml"
    ansible.limit = "all"
  end

  # ---- SSH Configuration ----
  config.ssh.insert_key = true
end
