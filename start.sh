#!/bin/bash
set -e

DCOS_GENERATE_CONFIG_PATH=${DCOS_GENERATE_CONFIG_PATH:-dcos_generate_config.sh}

containers=( sysd-dcos-master sysd-dcos-agent sysd-dcos-installer )

# cleanup old containers
for c in "${containers[@]}"; do
	docker rm -vf "${c}" 2>/dev/null || true
done

# build the image
docker build --rm --force-rm -t dcos-systemd-docker .

for c in "${containers[@]}"; do
	# start the container
	docker run -dt \
		--privileged \
		--tmpfs /run:rw --tmpfs /tmp:rw \
		-e "container=${c}" \
		--name "$c" \
		--hostname "$c" \
		-v $(pwd)/${DCOS_GENERATE_CONFIG_PATH}:/dcos_generate_config.sh \
		-v $(pwd)/genconf/config.yaml:/genconf/config.yaml \
		dcos-systemd-docker

	sleep 2

	# start docker
	docker exec "$c" systemctl start docker
	# start sshd
	docker exec "$c" systemctl start sshd
	# make sure docker is up
	docker exec "$c" docker ps -a
done

# get the ips
master_ip=$(docker inspect --format "{{.NetworkSettings.Networks.bridge.IPAddress}}" sysd-dcos-master)
agent_ip=$(docker inspect --format "{{.NetworkSettings.Networks.bridge.IPAddress}}" sysd-dcos-agent)

echo "Master IP: $master_ip"
echo "Agent  IP: $agent_ip"

# write to genconf/config.yaml
cat <<-EOF > "genconf/config.yaml"
---
agent_list:
- ${agent_ip}
bootstrap_url: file:///opt/dcos_install_tmp
cluster_name: DCOS
exhibitor_storage_backend: static
master_discovery: static
master_list:
- ${master_ip}
process_timeout: 10000
resolvers:
- 8.8.8.8
- 8.8.4.4
ssh_port: 22
ssh_user: root
superuser_password_hash: \$6\$rounds=656000\$5hVo9bKXfWRg1OCd\$3X2U4hI6RYvKFqm6hXtEeqnH2xE3XUJYiiQ/ykKlDXUie/0B6cuCZEfLe.dN/7jF5mx/vSkoLE5d1Zno20Z7Q0
superuser_username: admin
EOF

# generating config
echo "Generating config..."
docker exec sysd-dcos-installer ./dcos_generate_config.sh --genconf --offline -v

echo "Running preflight..."
docker exec sysd-dcos-installer ./dcos_generate_config.sh --preflight --offline -v

echo "Running deploy..."
docker exec sysd-dcos-installer ./dcos_generate_config.sh --deploy --offline -v

# remove the installer container
docker rm -f sysd-dcos-installer

echo "Master IP: $master_ip"
echo "Agent  IP: $agent_ip"
