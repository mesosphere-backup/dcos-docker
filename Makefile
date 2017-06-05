.DEFAULT_GOAL := all
include common.mk

.PHONY: all vagrant build build-all start postflight master agent public_agent installer clean-installer genconf registry open-browser preflight deploy clean clean-certs clean-containers clean-slice test hosts clean-hosts

# Set the number of DC/OS masters.
MASTERS := 1

# Set the number of DC/OS agents.
AGENTS := 1

# Set the number of DC/OS public agents.
PUBLIC_AGENTS := 1

ALL_AGENTS := $$(( $(PUBLIC_AGENTS)+$(AGENTS) ))

# Distro to test against
DISTRO := centos-7
MAIN_DOCKERFILE := $(CURDIR)/Dockerfile

# Variables for the files that get generated with the correct configurations.
CONFIG_FILE := $(CURDIR)/genconf/config.yaml
SERVICE_DIR := $(CURDIR)/include/systemd
DCOS_GENERATE_CONFIG_URL := https://downloads.dcos.io/dcos/stable/dcos_generate_config.sh
DCOS_GENERATE_CONFIG_PATH := $(CURDIR)/dcos_generate_config.sh
BOOTSTRAP_GENCONF_PATH := $(CURDIR)/genconf/serve/
BOOTSTRAP_TMP_PATH := /opt/dcos_install_tmp

# Detect default resolvers inside a docker container.
RESOLVERS := $(shell docker run --rm alpine cat /etc/resolv.conf | grep '^nameserver.*' | tr -s ' ' | cut -d' ' -f2 | paste -sd ' ' -)

DOCKER_SERVICE_FILE := $(SERVICE_DIR)/docker.service

SBIN_DIR := $(CURDIR)/include/sbin
DCOS_POSTFLIGHT_FILE := $(SBIN_DIR)/dcos-postflight

# Variables for the certs for a registry on the first master node.
CERTS_DIR := $(CURDIR)/include/certs
ROOTCA_CERT := $(CERTS_DIR)/cacert.pem
CLIENT_CSR := $(CERTS_DIR)/client.csr
CLIENT_KEY := $(CERTS_DIR)/client.key
CLIENT_CERT := $(CERTS_DIR)/client.cert

# Variables for the ssh keys that will be generated for installing DC/OS in the
# containers.
SSH_DIR := $(CURDIR)/include/ssh
SSH_ALGO := rsa
SSH_KEY := $(SSH_DIR)/id_$(SSH_ALGO)

# Variable for the path to the mesos executors systemd slice.
MESOS_SLICE := /run/systemd/system/mesos_executors.slice

# Detect the docker host's init system.
# Docker host may be remote (boot2docker).
# /proc/$PID/comm is only available in Linux 2.6.33 and later.
DOCKER_HOST_INIT_SYS := $(docker run $(INTERACTIVE) -v /proc:/host/proc:ro alpine cat /host/proc/1/comm)

# Disable Mesos systemd support when the docker host is not systemd.
# This is not officially supported or tested by DC/OS.
# Disabling MESOS_SYSTEMD_ENABLE_SUPPORT means that executors will be namespaced under the Mesos agent.
# So executors (and tasks) will be killed when the Mesos agent is restarted.
# This makes zero downtime in-place DC/OS upgrades impossible.
ifeq ($(DOCKER_HOST_INIT_SYS), systemd)
	MESOS_SYSTEMD_ENABLE_SUPPORT := true
else
	MESOS_SYSTEMD_ENABLE_SUPPORT := false
endif

# Variables for various docker arguments.
MASTER_MOUNTS :=
SYSTEMD_MOUNTS := \
	-v /sys/fs/cgroup:/sys/fs/cgroup:ro
VOLUME_MOUNTS := \
	-v /var/lib/docker \
	-v /opt
BOOTSTRAP_VOLUME_MOUNT := \
	-v $(BOOTSTRAP_GENCONF_PATH):$(BOOTSTRAP_TMP_PATH):ro
TMPFS_MOUNTS := \
	--tmpfs /run:rw,exec,nosuid,size=2097152k \
	--tmpfs /tmp:rw,exec,nosuid,size=2097152k
CERT_MOUNTS := \
	-v $(CERTS_DIR):/etc/docker/certs.d

# The home directory can be mounted as a development convenience.
# However, on some platforms, where $(HOME) is not set, we default to not mounting anything.
# Otherwise a mount of `::ro` would be attempted.
ifdef HOME
    HOME_MOUNTS := \
	-v $(HOME):$(HOME):ro
else
    HOME_MOUNTS :=
endif

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

build: generate $(DOCKER_SERVICE_FILE) $(DCOS_POSTFLIGHT_FILE) $(CURDIR)/genconf/ssh_key ## Build the docker image that will be used for the containers.
	@echo "+ Building the $(DISTRO) base image"
	@$(foreach distro,$(wildcard distros/$(DISTRO)*/Dockerfile),$(call build_distro_image,$(word 2,$(subst /, ,$(distro)))))
	@echo "+ Building the dcos-docker image"
	@docker tag $(DOCKER_IMAGE):$(DISTRO) $(DOCKER_IMAGE):base
	@docker build --rm --force-rm -t $(DOCKER_IMAGE) .


build-all: generate ## Build the Dockerfiles for all the various distros.
	@$(foreach distro,$(wildcard distros/*/Dockerfile),$(call build_distro_image,$(word 2,$(subst /, ,$(distro)))))

generate: $(CURDIR)/distros ## generate the Dockerfiles for all the distros.
	@$(CURDIR)/distros/generate.sh

$(SSH_DIR):
	@mkdir -p $@

$(SSH_KEY): $(SSH_DIR)
	@ssh-keygen -f $@ -t $(SSH_ALGO) -N ''

$(CURDIR)/genconf/ssh_key: $(SSH_KEY)
	@cp $(SSH_KEY) $@

start: build clean-certs $(CERTS_DIR) clean-containers master agent public_agent installer

postflight: ## Polls DC/OS until it is healthy (5m timeout)
	@docker exec $(INTERACTIVE) $(MASTER_CTR)1 dcos-postflight

master: ## Starts the containers for DC/OS masters.
	@echo "+ Starting master nodes"
	$(foreach NUM,$(shell [[ $(MASTERS) == 0 ]] || seq 1 1 $(MASTERS)),$(call start_dcos_container,$(MASTER_CTR),$(NUM),$(MASTER_MOUNTS) $(TMPFS_MOUNTS) $(CERT_MOUNTS) $(HOME_MOUNTS) $(VOLUME_MOUNTS)))

$(MESOS_SLICE):
	@if [ "$(MESOS_SYSTEMD_ENABLE_SUPPORT)" == "true" ]; then \
		echo -e '[Unit]\nDescription=Mesos Executors Slice' | sudo tee -a $@; \
		sudo systemctl start mesos_executors.slice; \
	fi


agent: $(MESOS_SLICE) ## Starts the containers for DC/OS agents.
	@echo "+ Starting agent nodes"
	$(foreach NUM,$(shell [[ $(AGENTS) == 0 ]] || seq 1 1 $(AGENTS)),$(call start_dcos_container,$(AGENT_CTR),$(NUM),$(TMPFS_MOUNTS) $(SYSTEMD_MOUNTS) $(CERT_MOUNTS) $(HOME_MOUNTS) $(VOLUME_MOUNTS)))

public_agent: $(MESOS_SLICE) ## Starts the containers for DC/OS public agents.
	@echo "+ Starting public agent nodes"
	$(foreach NUM,$(shell [[ $(PUBLIC_AGENTS) == 0 ]] || seq 1 1 $(PUBLIC_AGENTS)),$(call start_dcos_container,$(PUBLIC_AGENT_CTR),$(NUM),$(TMPFS_MOUNTS) $(SYSTEMD_MOUNTS) $(CERT_MOUNTS) $(HOME_MOUNTS) $(VOLUME_MOUNTS)))

$(DCOS_GENERATE_CONFIG_PATH):
	curl --fail --location --show-error -o $@ $(DCOS_GENERATE_CONFIG_URL)

installer: $(DCOS_GENERATE_CONFIG_PATH) ## Downloads the DC/OS installer.

clean-installer: ## Removes the DC/OS installer
	rm -f $(DCOS_GENERATE_CONFIG_PATH)

$(CONFIG_FILE): ips ## Writes the config file for the currently running containers.
	$(eval export CONFIG_BODY)
	echo "$$CONFIG_BODY" > $@

$(SERVICE_DIR):
	@mkdir -p $@

$(DOCKER_SERVICE_FILE): $(SERVICE_DIR) ## Writes the docker service file so systemd can run docker in our containers.
	$(eval export DOCKER_SERVICE_BODY)
	echo "$$DOCKER_SERVICE_BODY" > $@

$(SBIN_DIR):
	@mkdir -p $@

export DCOS_POSTFLIGHT_BODY
$(DCOS_POSTFLIGHT_FILE): $(SBIN_DIR) ## Writes the dc/os postflight script to verify installation.
	@echo "$$DCOS_POSTFLIGHT_BODY" > $@
	@chmod +x $@

$(CERTS_DIR):
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
	@bash $(DCOS_GENERATE_CONFIG_PATH) --genconf --offline -v

preflight: genconf ## Run the DC/OS installer with --preflight.
	@echo "+ Running preflight"
	@bash $(DCOS_GENERATE_CONFIG_PATH) --preflight --offline -v

deploy: preflight ## Run the DC/OS installer with --deploy.
	@echo "+ Running deploy"
	@bash $(DCOS_GENERATE_CONFIG_PATH) --deploy --offline -v

install: VOLUME_MOUNTS += $(BOOTSTRAP_VOLUME_MOUNT)
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
	@bash $(DCOS_GENERATE_CONFIG_PATH) --web --offline -v

clean-certs: ## Remove all the certs generated for the registry.
	$(RM) -r $(CERTS_DIR)

clean-containers: ## Removes and cleans up the master, agent, and installer containers.
	@docker rm -fv $(INSTALLER_CTR) > /dev/null 2>&1 || true
	$(foreach NUM,$(shell [[ $(MASTERS) == 0 ]] || seq 1 1 $(MASTERS)),$(call remove_container,$(MASTER_CTR),$(NUM)))
	$(foreach NUM,$(shell [[ $(AGENTS) == 0 ]] || seq 1 1 $(AGENTS)),$(call remove_container,$(AGENT_CTR),$(NUM)))
	$(foreach NUM,$(shell [[ $(PUBLIC_AGENTS) == 0 ]] || seq 1 1 $(PUBLIC_AGENTS)),$(call remove_container,$(PUBLIC_AGENT_CTR),$(NUM)))

clean-slice: ## Removes and cleanups up the systemd slice for the mesos executor.
	@if [ "$(MESOS_SYSTEMD_ENABLE_SUPPORT)" == "true" ]; then \
		sudo systemctl stop mesos_executors.slice; \
		sudo rm -f $(MESOS_SLICE); \
	fi

clean: clean-certs clean-containers clean-slice ## Stops all containers and removes all generated files for the cluster.
	$(RM) $(CURDIR)/genconf/ssh_key
	$(RM) $(CONFIG_FILE)
	$(RM) -r $(SSH_DIR)
	$(RM) -r $(SBIN_DIR)
	$(RM) dcos-genconf.*.tar

# Use SSH to execute tests because docker run/exec has a bug that breaks unbuffered pytest output.
# https://github.com/moby/moby/issues/8755 - Fixed in Docker 17.06+
test: ips ## Executes the integration tests
	@ssh -i $(CURDIR)/genconf/ssh_key -l root -p 22 -o StrictHostKeyChecking=no $(firstword $(MASTER_IPS)) " \
		set -o errexit -o nounset -o pipefail && \
        source /opt/mesosphere/environment.export && \
        source /opt/mesosphere/active/dcos-integration-test/util/test_env.export || \
          source /opt/mesosphere/active/dcos-integration-test/test_env.export || \
            true && \
        export SLAVE_HOSTS='$(subst ${space},${comma},$(AGENT_IPS))' && \
        export PUBLIC_SLAVE_HOSTS='$(subst ${space},${comma},$(PUBLIC_AGENT_IPS))' && \
        cd '$(DCOS_PYTEST_DIR)' && \
        $(DCOS_PYTEST_CMD) \
    "

hosts: ## Creates entries in /etc/hosts
	@echo "Before:"
	@grep "\.dcos" /etc/hosts || echo "<empty>"
	@$(call delete_host,\.dcos)
	@$(foreach NUM,$(shell [[ $(MASTERS) == 0 ]] || seq 1 1 $(MASTERS)), \
		$(call create_host,$(shell $(IP_CMD) $(MASTER_CTR)$(NUM)),m$(NUM).dcos) \
	)
	@$(foreach NUM,$(shell [[ $(AGENTS) == 0 ]] || seq 1 1 $(AGENTS)), \
		$(call create_host,$(shell $(IP_CMD) $(AGENT_CTR)$(NUM)),a$(NUM).dcos) \
	)
	@$(foreach NUM,$(shell [[ $(PUBLIC_AGENTS) == 0 ]] || seq 1 1 $(PUBLIC_AGENTS)), \
		$(call create_host,$(shell $(IP_CMD) $(PUBLIC_AGENT_CTR)$(NUM)),p$(NUM).dcos) \
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

# Define the function for building a distro's Dockerfile.
# @param distro	  Distro to build the Dockerfile for.
define build_distro_image
docker build --rm --force-rm -t $(DOCKER_IMAGE):$(1) distros/$(1)/;
docker tag  $(DOCKER_IMAGE):$(1) $(DOCKER_IMAGE):$(firstword $(subst -, ,$(1)));
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

# Define the postflight script to wait until DC/OS is up and running
define DCOS_POSTFLIGHT_BODY
#!/usr/bin/env bash
# Run the DC/OS diagnostic script for up to the specified number of seconds to ensure
# we do not return ERROR on a cluster that hasn't fully achieved quorum.
TIMEOUT_SECONDS="$${1:-900}"
function await() {
    until OUT=$$($${CMD} 2>&1) || [[ TIMEOUT_SECONDS -eq 0 ]]; do
        sleep 5
        let TIMEOUT_SECONDS=TIMEOUT_SECONDS-5
    done
    RETCODE=$$?
    if [[ "$${RETCODE}" != "0" ]]; then
        echo "DC/OS Unhealthy\\n\$${OUT}" >&2
        exit $${RETCODE}
    fi
}
CMD="curl --insecure --fail --location --silent http://127.0.0.1/"
echo "Polling web server ($${TIMEOUT_SECONDS}s timeout)..." >&2
await
if [[ -e "/opt/mesosphere/bin/3dt" ]]; then
    # DC/OS >= 1.7
    CMD="/opt/mesosphere/bin/3dt -diag"
    cfg_files=( /opt/mesosphere/packages/3dt*/endpoints_config.json )
    if [ $${#cfg_files[@]} -gt 0 ]; then
        # DC/OS >= 1.8
        # TODO: what if there's more than one? Which should we choose?
        CMD="$${CMD} -endpoint-config=$${cfg_files[0]}"
    fi
elif [[ -e "/opt/mesosphere/bin/dcos-diagnostics.py" ]]; then
    # DC/OS <= 1.6
    CMD="/opt/mesosphere/bin/dcos-diagnostics.py"
else
    echo "Postflight Failure: either 3dt or dcos-diagnostics.py must be present"
    exit 1
fi
echo "Polling component status ($${TIMEOUT_SECONDS}s timeout)..." >&2
await
echo "DC/OS Healthy" >&2
endef
