bind-mounting docker into nspawn containers breaks --volume

ssh from genconf container to master, slave containers seems kinda broken, hence --net=host in gen.sh

installer in nspawn dies with:

Failed to restart docker.service: Unit docker.service failed to load: No such file or directory.

if dcos-spartan.service is failing, modprobe dummy on the host before starting containers

modprobe is bind-mounted to /bin/true because dcos-spartan.service runs modprobe

lstat("/sys/fs/cgroup/systemd/mesos_executors.slice", 0x7ffec72735b0) = -1 ENOENT (No such file or directory)

/sys/fs/cgroup/systemd/machine.slice/machine-slave.scope/mesos_executors.slice

76a4e18d (Joris Van Remoortere 2015-09-23 17:46:45 -0700 125)   // If flags->runtime_directory doesn't exist, then we can't proceed.
76a4e18d (Joris Van Remoortere 2015-09-23 17:46:45 -0700 126)   if (!os::exists(CHECK_NOTNULL(systemd_flags)->runtime_directory)) {
76a4e18d (Joris Van Remoortere 2015-09-23 17:46:45 -0700 127)     return Error("Failed to locate systemd runtime directory: " +
76a4e18d (Joris Van Remoortere 2015-09-23 17:46:45 -0700 128)                  CHECK_NOTNULL(systemd_flags)->runtime_directory);
76a4e18d (Joris Van Remoortere 2015-09-23 17:46:45 -0700 129)   }

mesos-slave should probably be looking at ControlGroup= in systemctl show mesos_executors.slice

pam_securetty(login:auth): access denied: tty 'pts/0' is not secure !
rm -f /etc/securetty

dcos JAVA_HOME points to the jre directory which makes mesos configure sad
dcos java is missing jni.h because it's only a JRE now
will have to have a local jdk to do local dev
