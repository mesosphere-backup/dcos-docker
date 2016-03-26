bind-mounting docker into nspawn containers breaks --volume

ssh from genconf container to master, slave containers seems kinda broken, hence --net=host in gen.sh

installer in nspawn dies with:

Failed to restart docker.service: Unit docker.service failed to load: No such file or directory.

if dcos-spartan.service is failing, modprobe dummy on the host before starting containers

modprobe is bind-mounted to /bin/true because dcos-spartan.service runs modprobe
