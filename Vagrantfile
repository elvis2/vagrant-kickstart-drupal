# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

box      = 'box'
boxurl   = 'http://files.vagrantup.com/precise64.box'
hostname = 'box'
domain   = 'dev'
ip       = '192.168.0.42'
ram      = '4096'
cores	   = '2'
sync_source = '../../'
sync_target = '/home/vagrant'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  # Configure VM
  config.vm.box = box
  config.vm.box_url = boxurl
  config.vm.hostname = hostname + '.' + domain
  #config.vm.network :hostonly, ip
  config.vm.network :forwarded_port, guest: 80, host: 8080
  config.vm.network :forwarded_port, guest: 3306, host: 2201

  # set auto_update to false, if do NOT want to check the correct additions
  # version when booting this machine
  config.vbguest.auto_update = true

  # do NOT download the iso file from a webserver
  config.vbguest.no_remote = true

  # Now point outo the synced folders.
  #config.vm.synced_folder sync_source, sync_target

  config.vm.provider :virtualbox do |vb|

	  vb.customize [
		'modifyvm', :id,
		'--name', hostname,
		'--memory', ram,
		'--cpus', cores,
		'--ioapic', "on",
		'--pae', "on",
    '--chipset', "ich9"
	  ]

  end

config.vm.provision :shell, :path => "run.sh"

end
