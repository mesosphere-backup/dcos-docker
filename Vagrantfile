# -*- mode: ruby -*-
# vi: set ft=ruby :

$dcos_box = ENV.fetch('DCOS_BOX', 'mesosphere/dcos-centos-virtualbox')
$dcos_box_url = ENV.fetch('DCOS_BOX_URL', 'http://downloads.dcos.io/dcos-vagrant/metadata.json')
$dcos_box_version = ENV.fetch('DCOS_BOX_VERSION', '~> 0.7.0')

# configure vbox host-only network
system('./vagrant/vbox-network.sh')

def is_OS_X?
  (/.*darwin.*/ === RUBY_PLATFORM)
end

def add_route
  if is_OS_X?
    system('sudo route -nv add -net 172.17.0.0/16 192.168.65.50')
  else
    # Linux
    system('sudo ip route replace 172.17.0.0/16 via 192.168.65.50')
  end
end

def delete_route
  if is_OS_X?
    system('sudo route delete 172.17.0.0/16')
  else
    # Linux
    system('sudo ip route del 172.17.0.0/16')
  end
end

Vagrant.configure(2) do |config|
  # configure vagrant-vbguest plugin
  if Vagrant.has_plugin?('vagrant-vbguest')
    config.vbguest.auto_update = true
  end

  if Vagrant.has_plugin?('vagrant-triggers')
    config.trigger.after [:provision, :up, :reload] do
      add_route
    end

    config.trigger.after [:halt, :destroy] do
      delete_route
    end
  end

  config.vm.define 'dcos-docker' do |vm_cfg|
    vm_cfg.vm.box = $dcos_box
    vm_cfg.vm.box_url = $dcos_box_url
    vm_cfg.vm.box_version = $dcos_box_version

    vm_cfg.vm.hostname = 'dcos-docker'
    vm_cfg.vm.network :private_network, ip: '192.168.65.50'
    config.vm.synced_folder '.', '/vagrant', type: :virtualbox

    vm_cfg.vm.provider :virtualbox do |v|
      v.name = vm_cfg.vm.hostname
      v.cpus = 2
      v.memory = 8192
      # configure guest to use host DNS resolver
      v.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']
    end

    # Change home directory of "vagrant" user to /vagrant
    vm_cfg.vm.provision :shell, inline: "grep -q 'cd /vagrant' ~/.bash_profile || echo -e '\n[ -d /vagrant ] && cd /vagrant' >> ~/.bash_profile", privileged: false
  end
end
