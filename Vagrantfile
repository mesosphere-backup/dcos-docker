# -*- mode: ruby -*-
# vi: set ft=ruby :

require "yaml"

Vagrant.configure(2) do |config|
  # configure the vagrant-vbguest plugin
  if Vagrant.has_plugin?('vagrant-vbguest')
    config.vbguest.auto_update = true
  end

  config.vm.define "dcos-docker" do |vm_cfg|
    vm_cfg.vm.hostname = "dcos-docker"
    vm_cfg.vm.network "private_network", ip: "192.168.65.50"
    vm_cfg.vm.network "forwarded_port", guest: 80, guest_ip: "172.18.0.2", host: 80, host_ip: "172.18.0.2"
    vm_cfg.vm.network "forwarded_port", guest: 80, guest_ip: "172.18.0.3", host: 80, host_ip: "172.18.0.3"

    config.vm.provision :shell, path: "provision/guest.sh"

    config.vm.synced_folder '.', '/vagrant', type: "nfs"

    # allow explicit nil values in the cfg to override the defaults
    vm_cfg.vm.box = "ubuntu/wily64"
    vm_cfg.vm.box_version = "~> 20160329.0.0"

    vm_cfg.vm.provider "virtualbox" do |v|
      v.name = vm_cfg.vm.hostname
      v.cpus = 2
      v.memory = 4096
    end
  end
end
