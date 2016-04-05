.PHONY: all build start master agent installer ips genconf preflight deploy clean clean-containers help
SHELL := /bin/bash

# Set the number of DCOS masters.
MASTERS := 1

# Set the number of DCOS agents.
AGENTS := 1

# Set the superuser username
SUPERUSER_USERNAME := admin
SUPERUSER_PASSWORD_HASH := $$6$$rounds=656000$$5hVo9bKXfWRg1OCd$$3X2U4hI6RYvKFqm6hXtEeqnH2xE3XUJYiiQ/ykKlDXUie/0B6cuCZEfLe.dN/7jF5mx/vSkoLE5d1Zno20Z7Q0

# Variables for the resulting container & image names.
MASTER_CTR:= dcos-docker-master
AGENT_CTR := dcos-docker-agent
INSTALLER_CTR := dcos-docker-installer
DOCKER_IMAGE := mesosphere/dcos-docker

# Variable to set the correct Docker graphdriver to the currently running
# graphdriver. This makes docker in docker work more efficiently.
DOCKER_GRAPHDRIVER := $(if $(DOCKER_GRAPHDRIVER),$(DOCKER_GRAPHDRIVER),$(shell docker info | grep "Storage Driver" | sed 's/.*: //'))

DCOS_GENERATE_CONFIG_PATH := $(CURDIR)/dcos_generate_config.sh

# Variables for the files that get generated with the correct configurations.
CONFIG_FILE := $(CURDIR)/genconf/config.yaml
SERVICE_DIR := $(CURDIR)/include/systemd
DOCKER_SERVICE_FILE := $(SERVICE_DIR)/docker.service

# Variables for the ssh keys that will be generated for installing DCOS in the
# containers.
SSH_DIR := $(CURDIR)/include/ssh
SSH_ALGO := ed25519
SSH_KEY := $(SSH_DIR)/id_$(SSH_ALGO)

# Variable for the path to the mesos executors systemd slice.
MESOS_SLICE := /run/systemd/system/mesos_executors.slice

# Variables for various docker arguments.
COMMON_MOUNTS := \
	-v /home:/home:ro
SYSTEMD_MOUNTS := \
	-v /sys/fs/cgroup:/sys/fs/cgroup:ro
TMPFS_MOUNTS := \
	--tmpfs /run:rw \
	--tmpfs /tmp:rw
INSTALLER_MOUNTS := \
	-v $(CONFIG_FILE):/genconf/config.yaml \
	-v $(DCOS_GENERATE_CONFIG_PATH):/dcos_generate_config.sh
IP_CMD := docker inspect --format "{{.NetworkSettings.Networks.bridge.IPAddress}}"

all: clean-containers deploy ## Runs a full deploy of DCOS in containers.
	@echo "Master IP: $(MASTER_IPS)"
	@echo "Agent IP:  $(AGENT_IPS)"
	@echo "DCOS has been started, open http://$(firstword $(MASTER_IPS)) in your browser."

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

master: ## Starts the containers for dcos masters.
	$(foreach NUM,$(shell seq 1 $(MASTERS)),$(call start_dcos_container,$(MASTER_CTR),$(NUM),$(COMMON_MOUNTS) $(TMPFS_MOUNTS)))

$(MESOS_SLICE):
	@echo -e '[Unit]\nDescription=Mesos Executors Slice' | sudo tee -a $@
	@sudo systemctl start mesos_executors.slice

agent: $(MESOS_SLICE) ## Starts the containers for dcos agents.
	$(foreach NUM,$(shell seq 1 $(AGENTS)),$(call start_dcos_container,$(AGENT_CTR),$(NUM),$(COMMON_MOUNTS) $(TMPFS_MOUNTS) $(SYSTEMD_MOUNTS)))

installer: ## Starts the container for the dcos installer.
	@echo "+ Starting dcos installer"
ifeq (,$(wildcard $(DCOS_GENERATE_CONFIG_PATH)))
    $(error $(DCOS_GENERATE_CONFIG_PATH) does not exist, exiting!)
endif
	@touch $(CONFIG_FILE)
	@docker run -dt --privileged \
		$(COMMON_MOUNTS) \
		$(TMPFS_MOUNTS) \
		$(INSTALLER_MOUNTS) \
		--name $(INSTALLER_CTR) \
		-e "container=$(INSTALLER_CTR)" \
		--hostname $(INSTALLER_CTR) \
		$(DOCKER_IMAGE)
	@docker exec $(INSTALLER_CTR) systemctl start docker
	@docker exec $(INSTALLER_CTR) docker ps -a > /dev/null # just to make sure docker is up

ips: start ## Gets the ips for the currently running containers.
	$(foreach NUM,$(shell seq 1 $(MASTERS)),$(call get_master_ips,$(NUM)))
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

clean-containers: ## Removes and cleans up the master, agent, and installer containers.
	@docker rm -fv $(INSTALLER_CTR) > /dev/null 2>&1 || true
	@$(foreach NUM,$(shell seq 1 $(MASTERS)),$(call remove_container,$(MASTER_CTR),$(NUM)))
	@$(foreach NUM,$(shell seq 1 $(AGENTS)),$(call remove_container,$(AGENT_CTR),$(NUM)))

clean-slice: ## Removes and cleanups up the systemd slice for the mesos executor.
	@sudo systemctl start mesos_executors.slice
	@sudo rm -f $(MESOS_SLICE)

clean: clean-containers clean-slice ## Stops all containers and removes all generated files for the cluster.
	$(RM) $(CURDIR)/genconf/ssh_key
	$(RM) $(CONFIG_FILE)
	$(RM) -r $(SSH_DIR)
	$(RM) -r $(SERVICE_DIR)

help: ## Generate the Makefile help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# Define the function to start a master or agent container. This also starts
# docker and sshd in the resulting container, and makes sure docker started
# successfully.
# @param name	  First part of the container name.
# @param number	  ID of the container.
# @param mounts	  Specific mounts for the container.
define start_dcos_container
echo "+ Starting dcos container: $(1)$(2)";
docker run -dt --privileged \
	$(3) \
	--name $(1)$(2) \
	-e "container=$(1)$(2)" \
	--hostname $(1)$(2) \
	$(DOCKER_IMAGE);
sleep 2;
docker exec $(1)$(2) systemctl start docker;
docker exec $(1)$(2) systemctl start sshd;
docker exec $(1)$(2) docker ps -a > /dev/null;
endef

# Define the function to populate the MASTER_IPS variable with the
# corresponding IPs of the DCOS master containers.
# @param number	  ID of the container.
define get_master_ips
$(eval MASTER_IPS := $(MASTER_IPS) $(shell $(IP_CMD) $(MASTER_CTR)$(1)))
endef

# Define the function to populate the AGENT_IPS variable with the
# corresponding IPs of the DCOS agent containers.
# @param number	  ID of the container.
define get_agent_ips
$(eval AGENT_IPS := $(AGENT_IPS) $(shell $(IP_CMD) $(AGENT_CTR)$(1)))
endef

# Define the function to stop & remove a container.
# @param name	  First part of the container name.
# @param number	  ID of the container.
define remove_container
docker rm -fv $(1)$(2) > /dev/null 2>&1 || true;
endef

# Helper definitions.
null :=
space := ${null} ${null}
${space} := ${space} # ${ } is a space.
define newline

-
endef

# Define the template for the docker.service systemd unit file.
define DOCKER_SERVICE_BODY
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com

[Service]
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

# Define the template for genconf/config.yaml, this makes sure the correct IPs
# of the specific containers get populated correctly.
define CONFIG_BODY
---
agent_list:
- $(subst ${space},${newline} ,$(AGENT_IPS))
bootstrap_url: file:///opt/dcos_install_tmp
cluster_name: DCOS
exhibitor_storage_backend: static
master_discovery: static
master_list:
- $(subst ${space},${newline} ,$(MASTER_IPS))
process_timeout: 10000
resolvers:
- 8.8.8.8
- 8.8.4.4
ssh_port: 22
ssh_user: root
superuser_password_hash: $(SUPERUSER_PASSWORD_HASH)
superuser_username: $(SUPERUSER_USERNAME)
endef
