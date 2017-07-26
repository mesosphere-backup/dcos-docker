SHELL := /bin/bash

#########################
#### Config Includes ####
#########################

include make-defaults.mk

ifeq ($(shell test -e make-config.mk && echo yes),)
$(warning Missing config file (make-config.mk). Run `./configure` to generate it)
else
include make-config.mk
endif

###########################
#### Config Validation ####
###########################

ifneq ($(DOCKER_VERSION),1.11.2)
ifneq ($(DOCKER_VERSION),1.13.1)
$(error Only Docker versions 1.11.2 and 1.13.1 are supported)
endif
endif

ifeq ($(DOCKER_VERSION),1.11.2)
ifneq ($(DOCKER_STORAGEDRIVER),$(filter $(DOCKER_STORAGEDRIVER),overlay aufs))
$(error Only `overlay` and `aufs` storage drivers are supported for DinD for Docker version 1.11.2. Please check README.md for details)
endif
endif

ifeq ($(DOCKER_VERSION),1.13.1)
ifneq ($(DOCKER_STORAGEDRIVER),$(filter $(DOCKER_STORAGEDRIVER),overlay overlay2 aufs))
$(error Only `overlay`, `overlay2`, and `aufs` storage drivers are supported for DinD for Docker version 1.13.1. Please check README.md for details)
endif
endif

UNAME := $(shell uname)
OPEN_CMD := echo Unsupported OS (maybe you are on windows?) for opening url
ifeq ($(UNAME), Linux)
	OPEN_CMD := xdg-open
else ifeq ($(UNAME), Darwin)
	OPEN_CMD := open
endif

#########################
#### Common Commands ####
#########################

.PHONY: help
help: ## Generate the Makefile help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: ips
ips: ## Gets the ips for the currently running containers.
	@$(foreach NUM,$(shell [[ $(MASTERS) == 0 ]] || seq 1 1 $(MASTERS)),$(call exit_not_running_container,$(MASTER_CTR),$(NUM)))
	@$(foreach NUM,$(shell [[ $(AGENTS) == 0 ]] || seq 1 1 $(AGENTS)),$(call exit_not_running_container,$(AGENT_CTR),$(NUM)))
	@$(foreach NUM,$(shell [[ $(PUBLIC_AGENTS) == 0 ]] || seq 1 1 $(PUBLIC_AGENTS)),$(call exit_not_running_container,$(PUBLIC_AGENT_CTR),$(NUM)))
	$(foreach NUM,$(shell [[ $(MASTERS) == 0 ]] || seq 1 1 $(MASTERS)),$(call get_master_ips,$(NUM)))
	$(foreach NUM,$(shell [[ $(AGENTS) == 0 ]] || seq 1 1 $(AGENTS)),$(call get_agent_ips,$(NUM)))
	$(foreach NUM,$(shell [[ $(PUBLIC_AGENTS) == 0 ]] || seq 1 1 $(PUBLIC_AGENTS)),$(call get_public_agent_ips,$(NUM)))

###########################
#### Helper Function ####
###########################

IP_CMD := docker inspect --format "{{.NetworkSettings.Networks.bridge.IPAddress}}"
STATE_CMD := docker inspect --format "{{.State.Running}}"

null :=
space := ${null} ${null}
${space} := ${space} # ${ } is a space.
comma := ,
define newline

-
endef

# Define the function to populate the MASTER_IPS variable with the
# corresponding IPs of the DC/OS master containers.
# @param number	  ID of the container.
define get_master_ips
$(eval MASTER_IPS := $(MASTER_IPS) $(shell $(IP_CMD) $(MASTER_CTR)$(1)))
endef

# Define the function to populate the AGENT_IPS variable with the
# corresponding IPs of the DC/OS agent containers.
# @param number	  ID of the container.
define get_agent_ips
$(eval AGENT_IPS := $(AGENT_IPS) $(shell $(IP_CMD) $(AGENT_CTR)$(1)))
endef

define get_public_agent_ips
$(eval PUBLIC_AGENT_IPS := $(PUBLIC_AGENT_IPS) $(shell $(IP_CMD) $(PUBLIC_AGENT_CTR)$(1)))
endef

# Define the function to count the number of containers with the provided prefix
# @param name	First part of the container name.
count_running_containers = $(shell i=1; while docker inspect "$(1)$$i" &>/dev/null; do i=$$(($$i + 1)); done; echo "$$(($$i - 1))")

# Define the function to exit if a container is not running.
# @param name	  First part of the container name.
# @param number	  ID of the container.
define exit_not_running_container
if [[ "$(shell $(STATE_CMD) $(1)$(2))" != "true" ]]; then \
	>&2 echo "$(1)$(2) is not running"; \
	exit 1; \
fi;
endef

# Define the function to stop & remove a container.
# @param name	  First part of the container name.
# @param number	  ID of the container.
define remove_container
docker rm -fv $(1)$(2) &> /dev/null || true;
endef

# Define the function to add /etc/hosts entries.
# @param ip			IP address.
# @param hostname	Canonical Hostname to route to the IP address.
define create_host
echo "$(1)	$(2)" | $(call sudo_write,/etc/hosts) tee -a /etc/hosts > /dev/null
endef

# Define the function to add an alias to an existing /etc/hosts entry.
# @param ip			IP address.
# @param alias		Alias hostname to route to the IP address.
define create_host_alias
$(call sudo_write,/etc/hosts) sed -i="" "s/\(^$(1)[:space:]*.*\)/\1 $(2)/" /etc/hosts
endef

# Define the function to remove /etc/hosts entries.
# @param regex		Regex pattern for IP address or hostname.
define delete_host
$(call sudo_write,/etc/hosts) sed -i="" "/$(1)/d" /etc/hosts
endef

# Define the function to use sudo if required for file write access.
# Use this to avoid requiring password entry when unnecessary.
# @param path		Path to check for write access.
define sudo_write
$(shell [[ -w "/etc/hosts" ]] && echo -n "" || echo -n "sudo")
endef
