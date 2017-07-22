#########################
#### Config Defaults ####
#########################

# Path to the DC/OS installer
DCOS_GENERATE_CONFIG_PATH := $(CURDIR)/dcos_generate_config.sh

# URL to use when downloading the DC/OS installer (make installer)
DCOS_GENERATE_CONFIG_URL := https://downloads.dcos.io/dcos/stable/dcos_generate_config.sh

# Version of Docker to install on the DC/OS nodes
DOCKER_VERSION := 1.11.2

# Storage driver to use on the DC/OS nodes
DOCKER_STORAGEDRIVER := overlay

# Enable Mesos systemd support (requires systemd on Docker host)
# Disabling MESOS_SYSTEMD_ENABLE_SUPPORT means that executors will be namespaced under the Mesos agent.
# This causes executors (and tasks) to be killed when the Mesos agent is restarted.
# This makes zero downtime in-place DC/OS upgrades impossible.
MESOS_SYSTEMD_ENABLE_SUPPORT := true

# Number of DC/OS master nodes
MASTERS := 1

# Number of DC/OS agent nodes
AGENTS := 1

# Number of DC/OS public agent nodes
PUBLIC_AGENTS := 1

# Distro to use as the OS for the "node" containers
DISTRO := centos-7

# PORT to pass to the DC/OS installer
INSTALLER_PORT := 9000

# DCOS_INSTALLER_CONTAINER_NAME to pass to the DC/OS installer
INSTALLER_CTR := dcos-docker-installer

# Node container name prefixes
MASTER_CTR:= dcos-docker-master
AGENT_CTR := dcos-docker-agent
PUBLIC_AGENT_CTR := dcos-docker-pubagent

# Name of the Docker image to build and deploy
DOCKER_IMAGE := mesosphere/dcos-docker

# Test directory and command (make test)
DCOS_PYTEST_DIR := /opt/mesosphere/active/dcos-integration-test/
DCOS_PYTEST_CMD := py.test -vv

# Variable for the registry host
REGISTRY_HOST := registry.local

# Custom Docker volume arguments (passed to docker run)
# Syntax: -v [<host-path>:]<container-path>[:<mode>]
CUSTOM_MASTER_VOLUMES :=
CUSTOM_AGENT_VOLUMES :=
CUSTOM_PUBLIC_AGENT_VOLUMES :=

POSTFLIGHT_PROGRESS := --progress=dots

#########################################
#### Enterprise-only Config Defaults ####
#########################################

# SuperUser login username
SUPERUSER_USERNAME := admin

# The following is a hash of the password `admin`.
# A hash of a password can be obtained by running the following command:
#    bash dcos_generate_config.sh --hash-password admin | tail -1
# The password hash here is escaped.
# See https://stackoverflow.com/a/7860705 for details on escaping Makefile variables.
SUPERUSER_PASSWORD_HASH := $$6$$rounds=656000$$5hVo9bKXfWRg1OCd$$3X2U4hI6RYvKFqm6hXtEeqnH2xE3XUJYiiQ/ykKlDXUie/0B6cuCZEfLe.dN/7jF5mx/vSkoLE5d1Zno20Z7Q0
