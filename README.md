## mini-dcos

Run dcos with systemd and docker in two containers.

1. Put a `dcos_generate_config.sh` in the root of this directory.

2. From this directory run `make`.

**Makefile usage:**

```console
$ make help
agent                          Starts the container for a dcos agent.
build                          Build the docker image that will be used for the containers.
clean-files                    Removes the generated ssh keys, service files, etc for the cluster.
clean                          Removes and cleans up the master, agent, and installer containers.
deploy                         Run the dcos installer with --deploy.
genconf                        Run the dcos installer with --genconf.
help                           Generate the Makefile help
installer                      Starts the container for the dcos installer.
ips                            Gets the ips for the currently running containers.
master                         Starts the container for a dcos master.
preflight                      Run the dcos installer with --preflight.
```

### Requirements

- A Linux machine with systemd and docker installed.
