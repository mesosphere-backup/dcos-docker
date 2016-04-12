## dcos-docker

Run dcos with systemd and docker in two containers.

1. Put a `dcos_generate_config.sh` in the root of this directory.

2. From this directory run `make`.

> **NOTE**: This defaults to 1 master and 1 agent.
> You can change the number of masters by setting the variable `MASTERS`.
> You can change the number of agents by setting the variable `AGENTS`.
> For example `make MASTERS=3 AGENTS=5` will start 3 masters and 5 agents.

**Makefile usage:**

```console
$ make help
all                            Runs a full deploy of DCOS in containers.
agent                          Starts the containers for dcos agents.
build                          Build the docker image that will be used for the containers.
clean                          Stops all containers and removes all generated files for the cluster.
clean-containers               Removes and cleans up the master, agent, and installer containers.
clean-slice                    Removes and cleanups up the systemd slice for the mesos executor.
deploy                         Run the dcos installer with --deploy.
genconf                        Run the dcos installer with --genconf.
help                           Generate the Makefile help
installer                      Starts the container for the dcos installer.
integration-tests              Run the dcos-image integration tests on a dcos-docker instance.
ips                            Gets the ips for the currently running containers.
master                         Starts the containers for dcos masters.
preflight                      Run the dcos installer with --preflight.
registry                       Start a docker registry with certs in the mesos master.
```

### Requirements

- A Linux machine with systemd and docker installed.

> **NOTE**: If running `make integration-tests` you will also need the
> `openssl` command and to have the absolute path to your local checkout of
> dcos-image in `.path/dcos-image` in this repo.
