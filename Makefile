.DEFAULT_GOAL := all
include common.mk

.PHONY: all build start master agent installer genconf registry preflight deploy clean clean-containers help

# Set the number of DCOS masters.
MASTERS := 1

# Set the number of DCOS agents.
AGENTS := 1

# Variables for the files that get generated with the correct configurations.
CONFIG_FILE := $(CURDIR)/genconf/config.yaml
SERVICE_DIR := $(CURDIR)/include/systemd
DOCKER_SERVICE_FILE := $(SERVICE_DIR)/docker.service

# Variables for the certs for a registry on the first master node.
CERTS_DIR := $(CURDIR)/include/certs
ROOTCA_CERT := $(CERTS_DIR)/cacert.pem
CLIENT_CSR := $(CERTS_DIR)/client.csr
CLIENT_KEY := $(CERTS_DIR)/client.key
CLIENT_CERT := $(CERTS_DIR)/client.cert

# Variables for the ssh keys that will be generated for installing DCOS in the
# containers.
SSH_DIR := $(CURDIR)/include/ssh
SSH_ALGO := ed25519
SSH_KEY := $(SSH_DIR)/id_$(SSH_ALGO)

# Variable for the path to the mesos executors systemd slice.
MESOS_SLICE := /run/systemd/system/mesos_executors.slice

# Variables for various docker arguments.
MASTER_MOUNTS :=
SYSTEMD_MOUNTS := \
	-v /sys/fs/cgroup:/sys/fs/cgroup:ro
TMPFS_MOUNTS := \
	--tmpfs /run:rw \
	--tmpfs /tmp:rw
INSTALLER_MOUNTS := \
	-v $(CONFIG_FILE):/genconf/config.yaml \
	-v $(DCOS_GENERATE_CONFIG_PATH):/dcos_generate_config.sh
CERT_MOUNTS := \
	-v $(CERTS_DIR):/etc/docker/certs.d

IP_CMD := docker inspect --format "{{.NetworkSettings.Networks.bridge.IPAddress}}"

all: clean-containers deploy info ## Runs a full deploy of DCOS in containers.

info:
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

start: build $(CERTS_DIR) master agent installer

master: ## Starts the containers for dcos masters.
	$(foreach NUM,$(shell seq 1 $(MASTERS)),$(call start_dcos_container,$(MASTER_CTR),$(NUM),$(MASTER_MOUNTS) $(TMPFS_MOUNTS) $(CERT_MOUNTS)))

$(MESOS_SLICE):
	@echo -e '[Unit]\nDescription=Mesos Executors Slice' | sudo tee -a $@
	@sudo systemctl start mesos_executors.slice

agent: $(MESOS_SLICE) ## Starts the containers for dcos agents.
	$(foreach NUM,$(shell seq 1 $(AGENTS)),$(call start_dcos_container,$(AGENT_CTR),$(NUM),$(TMPFS_MOUNTS) $(SYSTEMD_MOUNTS) $(CERT_MOUNTS)))

installer: ## Starts the container for the dcos installer.
	@echo "+ Starting dcos installer"
ifeq (,$(wildcard $(DCOS_GENERATE_CONFIG_PATH)))
    $(error $(DCOS_GENERATE_CONFIG_PATH) does not exist, exiting!)
endif
	@touch $(CONFIG_FILE)
	@docker run -dt --privileged \
		$(TMPFS_MOUNTS) \
		$(INSTALLER_MOUNTS) \
		--name $(INSTALLER_CTR) \
		-e "container=$(INSTALLER_CTR)" \
		--hostname $(INSTALLER_CTR) \
		$(DOCKER_IMAGE)
	@sleep 2
	@docker exec $(INSTALLER_CTR) docker ps -a > /dev/null # just to make sure docker is up

$(CONFIG_FILE): ips ## Writes the config file for the currently running containers.
	$(file >$@,$(CONFIG_BODY))

$(SERVICE_DIR):
	@mkdir -p $@

$(DOCKER_SERVICE_FILE): $(SERVICE_DIR) ## Writes the docker service file so systemd can run docker in our containers.
	$(file >$@,$(DOCKER_SERVICE_BODY))

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
	@docker exec -it $(MASTER_CTR)1 \
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
	@echo "Your registry is reachable from inside the DCOS containers at:"
	@echo -e "\t$(REGISTRY_HOST):5000"
	@echo -e "\t$(REGISTRY_IP)"

genconf: start $(CONFIG_FILE) ## Run the dcos installer with --genconf.
	@echo "+ Running genconf"
	@docker exec $(INSTALLER_CTR) bash /dcos_generate_config.sh --genconf --offline -v

preflight: genconf ## Run the dcos installer with --preflight.
	@echo "+ Running preflight"
	@docker exec $(INSTALLER_CTR) bash /dcos_generate_config.sh --preflight --offline -v

deploy: preflight ## Run the dcos installer with --deploy.
	@echo "+ Running deploy"
	@docker exec $(INSTALLER_CTR) bash /dcos_generate_config.sh --deploy --offline -v
	-@docker rm -f $(INSTALLER_CTR) > /dev/null 2>&1 # remove the installer container we no longer need it

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
	$(RM) -r $(CERTS_DIR)

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
	--add-host "$(REGISTRY_HOST):$(shell $(IP_CMD) $(MASTER_CTR)1 2>/dev/null || echo 127.0.0.1)" \
	$(DOCKER_IMAGE);
sleep 2;
docker exec $(1)$(2) docker ps -a > /dev/null;
endef

# Define the function for moving the generated certs to the location for the IP
# or hostname for the registry.
# @param host	  Host or IP for the cert to be stored by.
define copy_registry_certs
mkdir -p $(CERTS_DIR)/$(1)
cp $(CLIENT_CERT) $(CERTS_DIR)/$(1)/
cp $(CLIENT_KEY) $(CERTS_DIR)/$(1)/
cp $(ROOTCA_CERT) $(CERTS_DIR)/$(1)/$(1).crt
endef

# Define the template for the docker.service systemd unit file.
define DOCKER_SERVICE_BODY
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=dbus.service

[Service]
ExecStart=/usr/bin/docker daemon -D -s ${DOCKER_GRAPHDRIVER}
MountFlags=slave
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
