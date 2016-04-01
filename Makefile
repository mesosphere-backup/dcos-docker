.PHONY: all build start master agent installer ips genconf preflight deploy clean clean-containers help
SHELL := /bin/bash

# set the number of agents
AGENTS := 3

# variables for container & image names
MASTER_CTR:= dcos-docker-master
AGENT_CTR := dcos-docker-agent
INSTALLER_CTR := dcos-docker-installer
DOCKER_IMAGE := mesosphere/dcos-docker
# set the graph driver as the current graphdriver if not set
DOCKER_GRAPHDRIVER := $(if $(DOCKER_GRAPHDRIVER),$(DOCKER_GRAPHDRIVER),$(shell docker info | grep "Storage Driver" | sed 's/.*: //'))

DCOS_GENERATE_CONFIG_PATH := $(CURDIR)/dcos_generate_config.sh

CONFIG_FILE := $(CURDIR)/genconf/config.yaml
SERVICE_DIR := $(CURDIR)/include/systemd
DOCKER_SERVICE_FILE := $(SERVICE_DIR)/docker.service

SSH_DIR := $(CURDIR)/include/ssh
SSH_ALGO := ed25519
SSH_KEY := $(SSH_DIR)/id_$(SSH_ALGO)

MESOS_SLICE := /run/systemd/system/mesos_executors.slice

# variables for various docker args
SYSTEMD_MOUNTS := \
	-v /sys/fs/cgroup:/sys/fs/cgroup:ro
TMPFS_MOUNTS := \
	--tmpfs /run:rw \
	--tmpfs /tmp:rw
INSTALLER_MOUNTS := \
	-v $(CONFIG_FILE):/genconf/config.yaml \
	-v $(DCOS_GENERATE_CONFIG_PATH):/dcos_generate_config.sh
IP_CMD := docker inspect --format "{{.NetworkSettings.Networks.bridge.IPAddress}}"

all: clean-containers deploy
	@echo "Master IP: $(MASTER_IP)"
	@echo "Agent IP:  $(AGENT_IPS)"
	@echo "Mini DCOS has been started, open http://$(MASTER_IP) in your browser."

build: $(DOCKER_SERVICE_FILE) $(CURDIR)/genconf/ssh_key ## Build the docker image that will be used for the containers.
	@echo "+ Building the docker image"
	@docker build --rm --force-rm -t $(DOCKER_IMAGE) .

$(SSH_DIR):
	@mkdir -p $@

$(SSH_KEY): $(SSH_DIR)
	@ssh-keygen -f $@ -t $(SSH_ALGO) -N ''

$(CURDIR)/genconf/ssh_key: $(SSH_KEY)
	@cp $(SSH_KEY) $@

start: build master agent installer

master: ## Starts the container for a dcos master.
	@echo "+ Starting dcos master"
	@docker run -dt --privileged \
		$(TMPFS_MOUNTS) \
		--name $(MASTER_CTR) \
		-e "container=$(MASTER_CTR)" \
		--hostname $(MASTER_CTR) \
		$(DOCKER_IMAGE)
	@docker exec $(MASTER_CTR) systemctl start docker
	@docker exec $(MASTER_CTR) systemctl start sshd
	@docker exec $(MASTER_CTR) docker ps -a > /dev/null # just to make sure docker is up

$(MESOS_SLICE):
	@echo -e '[Unit]\nDescription=Mesos Executors Slice' | sudo tee -a $@
	@sudo systemctl start mesos_executors.slice

define start_agent
echo "+ Starting dcos agent no. $(1)";
docker run -dt --privileged \
	$(TMPFS_MOUNTS) \
	$(SYSTEMD_MOUNTS) \
	--name $(AGENT_CTR)$(1)\
	-e "container=$(AGENT_CTR)$(1)" \
	--hostname $(AGENT_CTR)$(1) \
	$(DOCKER_IMAGE);
docker exec $(AGENT_CTR)$(1) systemctl start docker;
docker exec $(AGENT_CTR)$(1) systemctl start sshd;
docker exec $(AGENT_CTR)$(1) docker ps -a > /dev/null;
endef
agent: $(MESOS_SLICE) ## Starts the container for a dcos agent.
	$(foreach NUM,$(shell seq 1 $(AGENTS)),$(call start_agent,$(NUM)))

installer: ## Starts the container for the dcos installer.
	@echo "+ Starting dcos installer"
ifeq (,$(wildcard $(DCOS_GENERATE_CONFIG_PATH)))
    $(error $(DCOS_GENERATE_CONFIG_PATH) does not exist, exiting!)
endif
	@chmod +x $(DCOS_GENERATE_CONFIG_PATH)
	@touch $(CONFIG_FILE)
	@docker run -dt --privileged \
		$(TMPFS_MOUNTS) \
		$(INSTALLER_MOUNTS) \
		--name $(INSTALLER_CTR) \
		-e "container=$(INSTALLER_CTR)" \
		--hostname $(INSTALLER_CTR) \
		$(DOCKER_IMAGE)
	@docker exec $(INSTALLER_CTR) systemctl start docker
	@docker exec $(INSTALLER_CTR) docker ps -a > /dev/null # just to make sure docker is up

define get_agent_ips
$(eval AGENT_IPS := $(AGENT_IPS) $(shell $(IP_CMD) $(AGENT_CTR)$(1)))
endef
ips: start ## Gets the ips for the currently running containers.
	$(eval MASTER_IP := $(shell $(IP_CMD) $(MASTER_CTR)))
	$(foreach NUM,$(shell seq 1 $(AGENTS)),$(call get_agent_ips,$(NUM)))

$(CONFIG_FILE): ips ## Writes the config file for the currently running containers.
	$(file >$@,$(CONFIG_BODY))

$(SERVICE_DIR):
	@mkdir -p $@

$(DOCKER_SERVICE_FILE): $(SERVICE_DIR) ## Writes the docker service file so systemd can run docker in our containers.
	$(file >$@,$(DOCKER_SERVICE_BODY))

genconf: $(CONFIG_FILE) ## Run the dcos installer with --genconf.
	@echo "+ Running genconf"
	@docker exec $(INSTALLER_CTR) bash /dcos_generate_config.sh --genconf --offline -v

preflight: genconf ## Run the dcos installer with --preflight.
	@echo "+ Running preflight"
	@docker exec $(INSTALLER_CTR) bash /dcos_generate_config.sh --preflight --offline -v

deploy: preflight ## Run the dcos installer with --deploy.
	@echo "+ Running deploy"
	@docker exec $(INSTALLER_CTR) bash /dcos_generate_config.sh --deploy --offline -v
	@docker rm -f $(INSTALLER_CTR) > /dev/null 2>&1 # remove the installer container we no longer need it

define remove_container
docker rm -f $(AGENT_CTR)$(1) > /dev/null 2>&1 || true;
endef
clean-containers: ## Removes and cleans up the master, agent, and installer containers.
	@docker rm -f $(MASTER_CTR) $(INSTALLER_CTR) > /dev/null 2>&1 || true
	@$(foreach NUM,$(shell seq 1 $(AGENTS)),$(call remove_container,$(NUM)))

clean: clean-containers ## Stops all containers and removes all generated files for the cluster.
	@rm -f $(CURDIR)/genconf/ssh_key
	@rm -rf $(SSH_DIR)
	@rm -rf $(SERVICE_DIR)
	@sudo systemctl start mesos_executors.slice
	@sudo rm -f $(MESOS_SLICE)

help: ## Generate the Makefile help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# helper definitions
null :=
space := ${null} ${null}
${space} := ${space}# ${ } is a space.
define newline

-
endef

# define the template for docker.service
define DOCKER_SERVICE_BODY
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com

[Service]
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/bin/docker daemon -D -s ${DOCKER_GRAPHDRIVER}
MountFlags=slave
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
Delegate=yes
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
endef

# define the template for genconf/config.yaml
define CONFIG_BODY
---
agent_list:
- $(subst ${space},${newline} ,$(AGENT_IPS))
bootstrap_url: file:///opt/dcos_install_tmp
cluster_name: DCOS
exhibitor_storage_backend: static
master_discovery: static
master_list:
- ${MASTER_IP}
process_timeout: 10000
resolvers:
- 8.8.8.8
- 8.8.4.4
ssh_port: 22
ssh_user: root
superuser_password_hash: $$6$$rounds=656000$$5hVo9bKXfWRg1OCd$$3X2U4hI6RYvKFqm6hXtEeqnH2xE3XUJYiiQ/ykKlDXUie/0B6cuCZEfLe.dN/7jF5mx/vSkoLE5d1Zno20Z7Q0
superuser_username: admin
endef
