## dcos-docker

Run dcos with systemd and docker in two containers.

1. Put a `dcos_generate_config.sh` in the root of this directory.

2. From this directory run `make`.

> **NOTE**: This defaults to 3 masters and 3 agents.
> You can change the number of masters by setting the variable `MASTERS`.
> You can change the number of agents by setting the variable `AGENTS`.
> For example `make MASTER=1 AGENTS=5` will start 1 master and 5 agents.

**Makefile usage:**

```console
$ make help
all                            Runs a full deploy of DCOS in containers.
agent                          Starts the containers for dcos agents.
build                          Build the docker image that will be used for the containers.
clean                          Stops all containers and removes all generated files for the cluster.
deploy                         Run the dcos installer with --deploy.
genconf                        Run the dcos installer with --genconf.
help                           Generate the Makefile help
installer                      Starts the container for the dcos installer.
ips                            Gets the ips for the currently running containers.
master                         Starts the containers for dcos masters.
preflight                      Run the dcos installer with --preflight.
```

### Requirements

- A Linux machine with systemd and docker installed.
