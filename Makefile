# Since this Makefile was not designed with parallel execution in mind, opt
# out of any parallelism users might enable have via the `make` invocation.
.NOTPARALLEL:

.DEFAULT_GOAL := all
include make-common.mk

.PHONY: all vagrant build-base build-base-docker build build-all start postflight master agent public_agent installer clean-installer genconf registry open-browser preflight deploy clean clean-certs clean-containers clean-slice test vagrant-network clean-vagrant-network hosts clean-hosts

ALL_AGENTS := $$(( $(PUBLIC_AGENTS)+$(AGENTS) ))

# Installer variables
GENCONF_DIR_SRC := $(CURDIR)/genconf.src
GENCONF_DIR := $(CURDIR)/genconf
CONFIG_FILE := $(GENCONF_DIR)/config.yaml
INSTALLER_CMD := \
	PORT=${INSTALLER_PORT} \
	DCOS_INSTALLER_CONTAINER_NAME=${INSTALLER_CTR} \
	bash $(DCOS_GENERATE_CONFIG_PATH) --offline -v

# Bootstrap variables
BOOTSTRAP_GENCONF_PATH := $(GENCONF_DIR)/serve/
BOOTSTRAP_TMP_PATH := /opt/dcos_install_tmp

# Local docker systemd service variables
INCLUDE_DIR_SRC := $(CURDIR)/include.src
INCLUDE_DIR := $(CURDIR)/include
SERVICE_DIR_SRC := $(INCLUDE_DIR_SRC)/systemd
SERVICE_DIR := $(INCLUDE_DIR)/systemd
SBIN_DIR_SRC := $(INCLUDE_DIR_SRC)/sbin
SBIN_DIR := $(INCLUDE_DIR)/sbin

# Variables for the certs for a registry on the first master node.
CERTS_DIR := $(INCLUDE_DIR)/certs
ROOTCA_CERT := $(CERTS_DIR)/cacert.pem
CLIENT_CSR := $(CERTS_DIR)/client.csr
CLIENT_KEY := $(CERTS_DIR)/client.key
CLIENT_CERT := $(CERTS_DIR)/client.cert

# Variables for the ssh keys that will be generated for installing DC/OS in the
# containers.
SSH_DIR := $(INCLUDE_DIR)/ssh
SSH_ALGO := rsa
SSH_KEY := $(SSH_DIR)/id_$(SSH_ALGO)

# Variable for the path to the mesos executors systemd slice.
MESOS_SLICE := /run/systemd/system/mesos_executors.slice

# Variables for various docker arguments.
NODE_VOLUMES := \
	-v /var/lib/docker \
	-v /opt \
	--tmpfs /run:rw,exec,nosuid,size=2097152k \
	--tmpfs /tmp:rw,exec,nosuid,size=2097152k \
	-v $(CERTS_DIR):/etc/docker/certs.d
AGENT_VOLUMES := \
	-v /var/lib/mesos/slave \
	-v /sys/fs/cgroup:/sys/fs/cgroup:ro
BOOTSTRAP_VOLUMES := \
	-v $(BOOTSTRAP_GENCONF_PATH):$(BOOTSTRAP_TMP_PATH):ro

# if this session isn't interactive, then we don't want to allocate a
# TTY, which would fail, but if it is interactive, we do want to attach
# so that the user can send e.g. ^C through.
INTERACTIVE := -i
HAVE_TTY := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(HAVE_TTY), 1)
	INTERACTIVE += -t
endif

all: install info ## Runs a full deploy of DC/OS in containers.

vagrant:
	vagrant up
	vagrant ssh -c 'cd /vagrant && make'

info: ips ## Provides information about the master and agent's ips.
	@echo "Master IP: $(MASTER_IPS)"
	@echo "Agent IP:  $(AGENT_IPS)"
	@echo "Public Agent IP:  $(PUBLIC_AGENT_IPS)"
	@echo "Web UI: http://$(firstword $(MASTER_IPS))"

open-browser: ips ## Opens your browser to the master ip.
	$(OPEN_CMD) "http://$(firstword $(MASTER_IPS))"

build-base: generate $(SERVICE_DIR)/systemd-journald-init.service ## Build the base docker image.
	@echo "+ Building the base $(DISTRO) image"
	@$(foreach distro,$(wildcard build/base/$(DISTRO)*/Dockerfile),$(call build_base_image,$(word 3,$(subst /, ,$(distro)))))
	@docker tag $(DOCKER_IMAGE):base-$(DISTRO) $(DOCKER_IMAGE):base

build-base-docker: build-base $(SERVICE_DIR)/docker.service ## Build the base-docker (base + docker daemon) docker image.
	@echo "+ Building the base-docker $(DOCKER_VERSION) image"
	@$(call build_base_docker_image,$(DOCKER_VERSION))
	@docker tag $(DOCKER_IMAGE):base-docker-$(DOCKER_VERSION) $(DOCKER_IMAGE):base-docker

build: build-base-docker $(GENCONF_DIR)/ip-detect $(SBIN_DIR)/dcos-postflight $(GENCONF_DIR)/ssh_key ## Build the dcos-docker docker image used for all node containers.
	@echo "+ Building the dcos-docker image"
	@docker build --rm --force-rm -t $(DOCKER_IMAGE) .

build-all: generate ## Build the base and base-docker images for all permutations of distros and docker versions.
	@echo "+ Building the base images"
	@$(foreach distro,$(wildcard build/base/*/Dockerfile),$(call build_base_image,$(word 3,$(subst /, ,$(distro)))))
	@echo "+ Building the base-docker images"
	@$(foreach version,$(wildcard build/base-docker/*/Dockerfile),$(call build_base_docker_image,$(word 3,$(subst /, ,$(version)))))

generate: $(CURDIR)/build/base ## generate the Dockerfiles for all the base distros.
	@$(CURDIR)/build/base/generate.sh

$(SSH_DIR): $(INCLUDE_DIR)
	@mkdir -p $@

$(SSH_KEY): $(SSH_DIR)
	@ssh-keygen -f $@ -t $(SSH_ALGO) -N ''

$(GENCONF_DIR)/ssh_key: $(SSH_KEY)
	@cp $(SSH_KEY) $@

start: build clean-certs $(CERTS_DIR) clean-containers master agent public_agent installer

postflight: ## Polls DC/OS until it is healthy (5m timeout)
	@echo "+ Checking master nodes"
	$(foreach NUM,$(shell [[ $(MASTERS) == 0 ]] || seq 1 1 $(MASTERS)),$(call postflight_container,$(MASTER_CTR),$(NUM)))
	@echo "+ DC/OS Healthy (Master Nodes)"
	@echo "+ Checking agent nodes"
	$(foreach NUM,$(shell [[ $(AGENTS) == 0 ]] || seq 1 1 $(MASTERS)),$(call postflight_container,$(AGENT_CTR),$(NUM)))
	@echo "+ Checking public agent nodes"
	$(foreach NUM,$(shell [[ $(PUBLIC_AGENTS) == 0 ]] || seq 1 1 $(MASTERS)),$(call postflight_container,$(PUBLIC_AGENT_CTR),$(NUM)))
	@echo "+ DC/OS Healthy (All Nodes)"

master: $(BOOTSTRAP_GENCONF_PATH) ## Starts the containers for DC/OS masters.
	@echo "+ Starting master nodes"
	$(foreach NUM,$(shell [[ $(MASTERS) == 0 ]] || seq 1 1 $(MASTERS)),$(call start_dcos_container,$(MASTER_CTR),$(NUM),$(NODE_VOLUMES) $(CUSTOM_VOLUMES) $(CUSTOM_MASTER_VOLUMES)))

$(MESOS_SLICE):
	@if [ "$(MESOS_SYSTEMD_ENABLE_SUPPORT)" == "true" ]; then \
		echo -e '[Unit]\nDescription=Mesos Executors Slice' | sudo tee -a $@; \
		sudo systemctl start mesos_executors.slice; \
	fi

agent: $(BOOTSTRAP_GENCONF_PATH) $(MESOS_SLICE) ## Starts the containers for DC/OS agents.
	@echo "+ Starting agent nodes"
	$(foreach NUM,$(shell [[ $(AGENTS) == 0 ]] || seq 1 1 $(AGENTS)),$(call start_dcos_container,$(AGENT_CTR),$(NUM),$(NODE_VOLUMES) $(AGENT_VOLUMES) $(CUSTOM_VOLUMES) $(CUSTOM_AGENT_VOLUMES)))

public_agent: $(BOOTSTRAP_GENCONF_PATH) $(MESOS_SLICE) ## Starts the containers for DC/OS public agents.
	@echo "+ Starting public agent nodes"
	$(foreach NUM,$(shell [[ $(PUBLIC_AGENTS) == 0 ]] || seq 1 1 $(PUBLIC_AGENTS)),$(call start_dcos_container,$(PUBLIC_AGENT_CTR),$(NUM),$(NODE_VOLUMES) $(AGENT_VOLUMES) $(CUSTOM_VOLUMES) $(CUSTOM_PUBLIC_AGENT_VOLUMES)))

$(DCOS_GENERATE_CONFIG_PATH):
	curl --fail --location --show-error -o $@ $(DCOS_GENERATE_CONFIG_URL)

installer: $(DCOS_GENERATE_CONFIG_PATH) ## Downloads the DC/OS installer.

clean-installer: ## Removes the DC/OS installer
	rm -f $(DCOS_GENERATE_CONFIG_PATH)

$(GENCONF_DIR):
	@mkdir -p $@

$(GENCONF_DIR)/ip-detect: $(GENCONF_DIR) ## Writes the ip-detect script to return node IP.
	@cp $(GENCONF_DIR_SRC)/ip-detect $@
	@chmod +x $@

$(BOOTSTRAP_GENCONF_PATH):
	@mkdir -p $@

$(INCLUDE_DIR):
	@mkdir -p $@

$(CONFIG_FILE): ips ## Writes the config file for the currently running containers.
	$(eval export CONFIG_BODY)
	echo "$$CONFIG_BODY" > $@

$(SERVICE_DIR): $(INCLUDE_DIR)
	@mkdir -p $@

$(SERVICE_DIR)/docker.service: $(SERVICE_DIR) ## Writes the docker service file so systemd can run docker in our containers.
	$(eval export DOCKER_SERVICE_BODY)
	echo "$$DOCKER_SERVICE_BODY" > $@

$(SERVICE_DIR)/systemd-journald-init.service: $(SERVICE_DIR) ## Writes the systemd-journald-init service file so /run/log/journal has the correct permissions.
	@cp $(SERVICE_DIR_SRC)/systemd-journald-init.service $@

$(SBIN_DIR): $(INCLUDE_DIR)
	@mkdir -p $@

$(SBIN_DIR)/dcos-postflight: $(SBIN_DIR) ## Writes the dc/os postflight script to verify installation.
	@cp $(SBIN_DIR_SRC)/dcos-postflight $@
	@chmod +x $@

$(CERTS_DIR): $(INCLUDE_DIR)
	@mkdir -p $@

$(CERTS_DIR)/openssl-ca.cnf: $(CERTS_DIR)
	@cp $(CURDIR)/configs/certs/openssl-ca.cnf $@

$(ROOTCA_CERT): $(CERTS_DIR)/openssl-ca.cnf
	@openssl req -x509 \
		-config $(CERTS_DIR)/openssl-ca.cnf \
		-newkey rsa:4096 -sha256 \
		-subj "/C=US/ST=California/L=San Francisco/O=Mesosphere/CN=DCOS Test CA" \
		-nodes -out $@ -outform PEM
	@openssl x509 -noout -text -in $@

$(CERTS_DIR)/openssl-server.cnf: $(CERTS_DIR)
	@cp $(CURDIR)/configs/certs/openssl-server.cnf $@
	@echo "DNS.1 = $(REGISTRY_HOST)" >> $@
	@echo "IP.1 = $(firstword $(MASTER_IPS))" >> $@

$(CLIENT_CSR): ips $(CERTS_DIR)/openssl-server.cnf
	@openssl req \
		-config $(CERTS_DIR)/openssl-server.cnf \
		-newkey rsa:2048 -sha256 \
		-subj "/C=US/ST=California/L=San Francisco/O=Mesosphere/CN=$(REGISTRY_HOST)" \
		-nodes -out $@ -outform PEM
	@openssl req -text -noout -verify -in $@

$(CERTS_DIR)/index.txt: $(CERTS_DIR)
	@touch $@

$(CERTS_DIR)/serial.txt: $(CERTS_DIR)
	@echo '01' > $@

$(CLIENT_CERT): $(ROOTCA_CERT) $(CLIENT_CSR) $(CERTS_DIR)/index.txt $(CERTS_DIR)/serial.txt
	@openssl ca -batch \
		-config $(CERTS_DIR)/openssl-ca.cnf \
		-policy signing_policy -extensions signing_req \
		-out $@ -infiles $(CLIENT_CSR)
	@openssl x509 -noout -text -in $@

registry: $(CLIENT_CERT) ## Start a docker registry with certs in the mesos master.
	@docker exec $(INTERACTIVE) $(MASTER_CTR)1 \
		docker run \
		-d --restart=always \
		-p 5000:5000 \
		-v /etc/docker/certs.d:/certs \
		-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/client.cert \
  		-e REGISTRY_HTTP_TLS_KEY=/certs/client.key \
		--name registry \
  		registry:2
	@$(eval REGISTRY_IP := $(firstword $(MASTER_IPS)):5000)
	@$(call copy_registry_certs,$(REGISTRY_IP))
	@$(call copy_registry_certs,$(REGISTRY_HOST):5000)
	@echo "Your registry is reachable from inside the DC/OS containers at:"
	@echo -e "\t$(REGISTRY_HOST):5000"
	@echo -e "\t$(REGISTRY_IP)"

genconf: start $(CONFIG_FILE) ## Run the DC/OS installer with --genconf.
	$(RM) dcos-genconf.*.tar ## Remove tar files from previous runs;  otherwise we might skip building Docker image
	@echo "+ Running genconf"
	$(INSTALLER_CMD) --genconf

preflight: genconf ## Run the DC/OS installer with --preflight.
	@echo "+ Running preflight"
	$(INSTALLER_CMD) --preflight

deploy: preflight ## Run the DC/OS installer with --deploy.
	@echo "+ Running deploy"
	$(INSTALLER_CMD) --deploy

install: NODE_VOLUMES += $(BOOTSTRAP_VOLUMES)
install: genconf ## Install DC/OS using "advanced" method
	@echo "+ Running dcos_install.sh on masters"
	$(foreach NUM,$(shell [[ $(MASTERS) == 0 ]] || seq 1 1 $(MASTERS)),$(call run_dcos_install_in_container,$(MASTER_CTR),$(NUM),master))
	@echo "+ Running dcos_install.sh on agents"
	$(foreach NUM,$(shell [[ $(AGENTS) == 0 ]] || seq 1 1 $(AGENTS)),$(call run_dcos_install_in_container,$(AGENT_CTR),$(NUM),slave))
	@echo "+ Running dcos_install.sh on public agents"
	$(foreach NUM,$(shell [[ $(PUBLIC_AGENTS) == 0 ]] || seq 1 1 $(PUBLIC_AGENTS)),$(call run_dcos_install_in_container,$(PUBLIC_AGENT_CTR),$(NUM),slave_public))
	@echo "DC/OS node setup in progress. Run 'make postflight' to block until they are ready."

web: preflight ## Run the DC/OS installer with --web.
	@echo "+ Running web"
	$(INSTALLER_CMD) --web

clean-certs: ## Remove all the certs generated for the registry.
	$(RM) -r $(CERTS_DIR)

clean-containers: ## Removes and cleans up all master, agent, and installer containers.
	@docker rm -fv $(INSTALLER_CTR) > /dev/null 2>&1 || true
	$(foreach NUM,$(shell MAX=$(call count_running_containers,$(MASTER_CTR)) && [[ $$MAX == 0 ]] || seq 1 1 $$MAX),$(call remove_container,$(MASTER_CTR),$(NUM))${newline})
	$(foreach NUM,$(shell MAX=$(call count_running_containers,$(AGENT_CTR)) && [[ $$MAX == 0 ]] || seq 1 1 $$MAX),$(call remove_container,$(AGENT_CTR),$(NUM))${newline})
	$(foreach NUM,$(shell MAX=$(call count_running_containers,$(PUBLIC_AGENT_CTR)) && [[ $$MAX == 0 ]] || seq 1 1 $$MAX),$(call remove_container,$(PUBLIC_AGENT_CTR),$(NUM))${newline})

clean-slice: ## Removes and cleanups up the systemd slice for the mesos executor.
	@if [ "$(MESOS_SYSTEMD_ENABLE_SUPPORT)" == "true" ]; then \
		sudo systemctl stop mesos_executors.slice; \
		sudo rm -f $(MESOS_SLICE); \
	fi

clean: clean-containers clean-slice clean-certs ## Stops all containers and removes all generated files for the cluster.
	$(RM) -r $(GENCONF_DIR)
	$(RM) -r $(INCLUDE_DIR)
	$(RM) dcos-genconf.*.tar

# Use SSH to execute tests because docker run/exec has a bug that breaks unbuffered pytest output.
# https://github.com/moby/moby/issues/8755 - Fixed in Docker 17.06+
export TEST_INTEGRATION
test: ips ## Executes the integration tests
	[ -f ~/.ssh/known_hosts ] && ssh-keygen -R $(firstword $(MASTER_IPS)) || true
	echo "$$TEST_INTEGRATION" | ssh -T -i $(GENCONF_DIR)/ssh_key -l root -p 22 -o StrictHostKeyChecking=no $(firstword $(MASTER_IPS))

vagrant-network:
	@VNET="$(vagrant_network)"; \
	if [[ -z "$${VNET}" ]]; then \
		echo "Creating network..."; \
		VNET="$$(VBoxManage hostonlyif create | grep 'successfully created' | sed "s/Interface '\(.*\)' was successfully created/\1/")"; \
		echo "Configuring network: $${VNET}..."; \
		VBoxManage hostonlyif ipconfig --ip 192.168.65.1 "$${VNET}"; \
		echo "Enabling network: $${VNET}..."; \
		if hash ip 2>/dev/null; then \
			sudo ip link set "$${VNET}" up; \
			echo "Routing Docker IPs to VM..."; \
			sudo ip route replace 172.17.0.0/16 via 192.168.65.50; \
		else \
			sudo ifconfig "$${VNET}" up; \
			echo "Adding Docker IP routes (172.17.0.0/16)..."; \
			sudo route -nv add -net 172.17.0.0/16 192.168.65.50; \
		fi; \
		echo "Vagrant Network Setup Complete!"; \
	fi

clean-vagrant-network:
	@VNET="$(vagrant_network)"; \
	if [[ -n "$${VNET}" ]]; then \
		echo "Deleting Docker IP routes (172.17.0.0/16)..."; \
		if hash ip 2>/dev/null; then \
			sudo ip route del 172.17.0.0/16; \
			echo "Disabling network: $${VNET}..."; \
			sudo ip link set "$${VNET}" down; \
		else \
			sudo route delete 172.17.0.0/16; \
			echo "Disabling network: $${VNET}..."; \
			sudo ifconfig "$${VNET}" down; \
		fi; \
		echo "Deleting network..."; \
		VBoxManage hostonlyif remove "$${VNET}"; \
		echo "Vagrant Network Teardown Complete!"; \
	fi

hosts: ## Creates entries in /etc/hosts
	@echo "Before:"
	@grep "\.dcos" /etc/hosts || echo "<empty>"
	@$(call delete_host,\.dcos)
	@$(foreach NUM,$(shell [[ $(MASTERS) == 0 ]] || seq 1 1 $(MASTERS)), \
		$(call create_host,$(shell $(IP_CMD) $(MASTER_CTR)$(NUM)),m$(NUM).dcos); \
	)
	@$(foreach NUM,$(shell [[ $(AGENTS) == 0 ]] || seq 1 1 $(AGENTS)), \
		$(call create_host,$(shell $(IP_CMD) $(AGENT_CTR)$(NUM)),a$(NUM).dcos); \
	)
	@$(foreach NUM,$(shell [[ $(PUBLIC_AGENTS) == 0 ]] || seq 1 1 $(PUBLIC_AGENTS)), \
		$(call create_host,$(shell $(IP_CMD) $(PUBLIC_AGENT_CTR)$(NUM)),p$(NUM).dcos); \
	)
	@if [[ $(PUBLIC_AGENTS) != 0 ]]; then \
		$(call create_host_alias,$(shell $(IP_CMD) $(PUBLIC_AGENT_CTR)1),oinker.acme.org); \
	fi
	@echo "After:"
	@grep "\.dcos" /etc/hosts || echo "<empty>"

clean-hosts: ## Deletes dcos entries in /etc/hosts
	@echo "Before:"
	@grep "\.dcos" /etc/hosts || echo "<empty>"
	@$(call delete_host,\.dcos)
	@echo "After:"
	@grep "\.dcos" /etc/hosts || echo "<empty>"

# Define the function to start a master or agent container. This also starts
# docker and sshd in the resulting container, and makes sure docker started
# successfully.
#
# A supported configuration includes systemd on the host. In these
# configurations, Mesos uses systemd. There is experimentatl support for
# running Mesos without systemd support. A configuration file which is common
# to agents and public agents is either created or added to.
# This configuration file specifies whether Mesos should or should not enable systemd.
# This file path is referred to in the `dcos-mesos-slave.service` configuration.
# @param name	  First part of the container name.
# @param number	  ID of the container.
# @param mounts	  Specific mounts for the container.
define start_dcos_container
echo "+ Starting DC/OS container: $(1)$(2)";
docker run -dt --privileged \
	$(3) \
	--name $(1)$(2) \
	-e "container=$(1)$(2)" \
	-e DCOS_PYTEST_DIR='$(DCOS_PYTEST_DIR)' \
	-e DCOS_PYTEST_CMD='$(DCOS_PYTEST_CMD)' \
	-e DCOS_NUM_AGENTS=$(ALL_AGENTS) \
	-e DCOS_NUM_MASTERS=$(MASTERS) \
	--hostname $(1)$(2) \
	--add-host "$(REGISTRY_HOST):$(shell $(IP_CMD) $(MASTER_CTR)1 2>/dev/null || echo 127.0.0.1)" \
	$(DOCKER_IMAGE);
sleep 2;
docker exec $(1)$(2) mkdir -p /var/lib/dcos
docker exec $(1)$(2) /bin/bash -c -o errexit -o nounset -o pipefail \
	"echo 'MESOS_SYSTEMD_ENABLE_SUPPORT=$(MESOS_SYSTEMD_ENABLE_SUPPORT)' >> /var/lib/dcos/mesos-slave-common"
docker exec $(1)$(2) systemctl start sshd.service;
docker exec $(1)$(2) docker ps -a > /dev/null;
endef

# Define the function to run dcos_install.sh in a master or agent container
# @param name	First part of the container name.
# @param number	ID of the container.
# @param role	DC/OS role of the container
define run_dcos_install_in_container
echo "+ Starting dcos_install.sh $(3) container: $(1)$(2)";
docker exec $(1)$(2) /bin/bash $(BOOTSTRAP_TMP_PATH)/dcos_install.sh --no-block-dcos-setup $(3);
endef

# Define the function for moving the generated certs to the location for the IP
# or hostname for the registry.
# @param host	  Host or IP for the cert to be stored by.
define copy_registry_certs
mkdir -p $(CERTS_DIR)/$(1);
cp $(CLIENT_CERT) $(CERTS_DIR)/$(1)/;
cp $(CLIENT_KEY) $(CERTS_DIR)/$(1)/;
cp $(ROOTCA_CERT) $(CERTS_DIR)/$(1)/$(1).crt;
endef

# Define the function for building a base distro's Dockerfile.
# @param distro	  Distro to build the base Dockerfile for.
define build_base_image
docker build --rm --force-rm -t $(DOCKER_IMAGE):base-$(1) --file build/base/$(1)/Dockerfile .;
docker tag  $(DOCKER_IMAGE):base-$(1) $(DOCKER_IMAGE):$(firstword $(subst -, ,$(1)));
endef

# Define the function for building a base-docker Dockerfile.
# @param version	  Docker version to include.
define build_base_docker_image
docker build --rm --force-rm -t $(DOCKER_IMAGE):base-docker-$(1) --file build/base-docker/$(1)/Dockerfile .;
endef

# Define the template for the docker.service systemd unit file.
define DOCKER_SERVICE_BODY
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=dbus.service

[Service]
ExecStart=/usr/bin/docker daemon -D -s ${DOCKER_STORAGEDRIVER} \
	--disable-legacy-registry=true \
	--exec-opt=native.cgroupdriver=cgroupfs
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
Delegate=yes
TimeoutStartSec=0

[Install]
WantedBy=default.target
endef

# Define the template for genconf/config.yaml, this makes sure the correct IPs
# of the specific containers get populated correctly.

# EXTRA_GENCONF_CONFIG is a way to add extra config parameters in scripts
# calling out dcos-docker.
EXTRA_GENCONF_CONFIG :=
define CONFIG_BODY
---
agent_list:
- $(subst ${space},${newline} ,$(AGENT_IPS))
public_agent_list:
- $(subst ${space},${newline} ,$(PUBLIC_AGENT_IPS))
bootstrap_url: file://$(BOOTSTRAP_TMP_PATH)
cluster_name: DCOS
exhibitor_storage_backend: static
master_discovery: static
master_list:
- $(subst ${space},${newline} ,$(MASTER_IPS))
process_timeout: 10000
resolvers:
- $(subst ${space},${newline} ,$(RESOLVERS))
ssh_port: 22
ssh_user: root
superuser_password_hash: $(SUPERUSER_PASSWORD_HASH)
superuser_username: $(SUPERUSER_USERNAME)
platform: docker
check_time: false
$(EXTRA_GENCONF_CONFIG)
endef

# Define the function to run postflight on a specific node.
# @param name	  First part of the container name.
# @param number	  ID of the container.
define postflight_container
@echo "+ Checking node health ($(1)$(2))"
@docker exec $(INTERACTIVE) $(1)$(2) dcos-postflight $(POSTFLIGHT_PROGRESS)
@echo "+ Node Healthy ($(1)$(2))"
endef

define TEST_INTEGRATION
#!/usr/bin/env bash
set -o errexit -o nounset -o pipefail -o xtrace
source /opt/mesosphere/environment.export
source /opt/mesosphere/active/dcos-integration-test/util/test_env.export || true # old location
source /opt/mesosphere/active/dcos-integration-test/test_env.export || true # old location
export MASTER_HOSTS='$(subst ${space},${comma},$(MASTER_IPS))'
export SLAVE_HOSTS='$(subst ${space},${comma},$(AGENT_IPS))'
export PUBLIC_SLAVE_HOSTS='$(subst ${space},${comma},$(PUBLIC_AGENT_IPS))'
cd '$(DCOS_PYTEST_DIR)'
$(DCOS_PYTEST_CMD)
endef

# Define the function to lookup the vagrant host-only network name
define vagrant_network
$(shell VBoxManage list hostonlyifs | grep '^Name:\|IPAddress:' | sed 's/^.*:[[:space:]]*//g' | grep -B 1 '^192.168.65.1$$' | head -1)
endef
