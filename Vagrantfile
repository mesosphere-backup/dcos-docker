# -*- mode: ruby -*-
# vi: set ft=ruby :

require "yaml"

Vagrant.configure(2) do |config|
  # configure the vagrant-hostmanager plugin
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.ignore_private_ip = false

  # configure the vagrant-vbguest plugin
  if Vagrant.has_plugin?('vagrant-vbguest')
    config.vbguest.auto_update = true
  end

  config.vm.define "dcos" do |vm_cfg|
    vm_cfg.vm.hostname = "dcos"
    vm_cfg.vm.network "private_network", ip: "192.168.65.50"

    config.vm.synced_folder '.', '/vagrant', type: "nfs"

    # allow explicit nil values in the cfg to override the defaults
    vm_cfg.vm.box = "mesosphere/dcos-centos-virtualbox"
    vm_cfg.vm.box_url = "https://downloads.mesosphere.com/dcos-vagrant/metadata.json"
    vm_cfg.vm.box_version = "~> 0.4.1"

    vm_cfg.vm.provider "virtualbox" do |v|
      v.name = vm_cfg.vm.hostname
      v.cpus = 2
      v.memory = 4096
      v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    end
  end
end
