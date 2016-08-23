# -*- mode: ruby -*-
# vi: set ft=ruby :

$dcos_box = ENV.fetch("DCOS_BOX", "mesosphere/dcos-centos-virtualbox")
$dcos_box_url = ENV.fetch("DCOS_BOX_URL", "http://downloads.dcos.io/dcos-vagrant/metadata.json")
$dcos_box_version = ENV.fetch("DCOS_BOX_VERSION", nil)

# configure vbox host-only network
system('./vagrant/vbox-network.sh')

Vagrant.configure(2) do |config|
  # configure vagrant-vbguest plugin
  if Vagrant.has_plugin?('vagrant-vbguest')
    config.vbguest.auto_update = true
  end

  config.vm.define 'dcos-docker' do |vm_cfg|
    vm_cfg.vm.box = $dcos_box
    vm_cfg.vm.box_url = $dcos_box_url
    vm_cfg.vm.box_version = $dcos_box_version

    vm_cfg.vm.hostname = 'dcos-docker'
    vm_cfg.vm.network :private_network, ip: '192.168.65.50'
    config.vm.synced_folder '.', '/vagrant', type: :virtualbox

    vm_cfg.vm.provider "virtualbox" do |v|
      v.name = vm_cfg.vm.hostname
      v.cpus = 2
      v.memory = 8192
      # configure guest to use host DNS resolver
      v.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']
    end
  end
end
