# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"
  config.vm.hostname = "ecommerce-vm"
  config.vm.boot_timeout = 600

  # Network Configuration
  config.vm.network "private_network", ip: "192.168.56.10"
  config.vm.network "forwarded_port", guest: 222,  host: 2222,  id: "ssh-custom"
  config.vm.network "forwarded_port", guest: 8000, host: 8000,  id: "app"
  config.vm.network "forwarded_port", guest: 9100, host: 9100,  id: "node-exporter"

  # VM Resources
  config.vm.provider "virtualbox" do |vb|
    vb.name = "ecommerce-vm"
    vb.memory = "8192"
    vb.cpus = 3
  end

  config.vm.usable_port_range = 2200..2250

  # Install Python 3 for Ansible
  config.vm.provision "shell", inline: <<-SHELL
    apt-get update
    apt-get install -y python3 python3-pip
  SHELL

  # Ansible Provisioner
  config.vm.provision "ansible_local" do |ansible|
    ansible.playbook = "ansible/playbook.yml"
    ansible.provisioning_path = "/vagrant"
    ansible.inventory_path = "ansible/inventory/hosts.yml"
    ansible.limit = "all"
  end

  config.ssh.insert_key = true
end
