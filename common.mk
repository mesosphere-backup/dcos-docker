SHELL := /bin/bash

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

# Variable for the registry host
REGISTRY_HOST := registry.local

.PHONY: help
help: ## Generate the Makefile help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: ips
ips: ## Gets the ips for the currently running containers.
	$(foreach NUM,$(shell seq 1 $(MASTERS)),$(call get_master_ips,$(NUM)))
	$(foreach NUM,$(shell seq 1 $(AGENTS)),$(call get_agent_ips,$(NUM)))

# Helper definitions.
null :=
space := ${null} ${null}
${space} := ${space} # ${ } is a space.
comma := ,
define newline

-
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
