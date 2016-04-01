.PHONY: all build start master agent installer ips genconf preflight deploy clean help

# variables for container & image names
MASTER_CTR:= mini-dcos-master
AGENT_CTR := mini-dcos-agent
INSTALLER_CTR := mini-dcos-installer
DOCKER_IMAGE := mesosphere/mini-dcos

DCOS_GENERATE_CONFIG_PATH := $(CURDIR)/dcos_generate_config.sh

CONFIG_FILE := $(CURDIR)/genconf/config.yaml

# variables for various docker args
SYSTEMD_MOUNTS := \
	-v /sys/fs/cgroup:/sys/fs/cgroup:ro \
	-v /var/run/systemd/system:/var/run/systemd/system
TMPFS_MOUNTS := \
	--tmpfs /run:rw \
	--tmpfs /tmp:rw
INSTALLER_MOUNTS := \
	-v $(CONFIG_FILE):/genconf/config.yaml \
	-v $(DCOS_GENERATE_CONFIG_PATH):/dcos_generate_config.sh
IP_CMD := docker inspect --format "{{.NetworkSettings.Networks.bridge.IPAddress}}"

all: deploy
	@echo "Master IP: $(MASTER_IP)"
	@echo "Agent IP:  $(AGENT_IP)"

build: ## Build the docker image that will be used for the containers.
	@echo "+ Building the docker image"
	@docker build --rm --force-rm -t $(DOCKER_IMAGE) .

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

agent: ## Starts the container for a dcos agent.
	@echo "+ Starting dcos agent"
	docker run -dt --privileged \
		$(TMPFS_MOUNTS) \
		$(SYSTEMD_MOUNTS) \
		--name $(AGENT_CTR) \
		-e "container=$(AGENT_CTR)" \
		--hostname $(AGENT_CTR) \
		$(DOCKER_IMAGE)
	@docker exec $(AGENT_CTR) systemctl start docker
	@docker exec $(AGENT_CTR) systemctl start sshd
	@docker exec $(AGENT_CTR) docker ps -a > /dev/null # just to make sure docker is up

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

ips: start ## Gets the ips for the currently running containers.
	$(eval MASTER_IP := $(shell $(IP_CMD) $(MASTER_CTR)))
	$(eval AGENT_IP := $(shell $(IP_CMD) $(AGENT_CTR)))

define newline


endef
define CONFIG_BODY
---
agent_list:
- ${AGENT_IP}
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
$(CONFIG_FILE): ips ## Writes the config file for the currently running containers.
	@echo -e '$(subst $(newline),\n,${CONFIG_BODY})' > $(CONFIG_FILE)

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

clean: ## Removes and cleans up the master, agent, and installer containers.
	@docker rm -f $(MASTER_CTR) $(AGENT_CTR) $(INSTALLER_CTR) > /dev/null 2>&1

help: ## Generate the Makefile help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
