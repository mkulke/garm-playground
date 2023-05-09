#!/bin/bash

set -euo pipefail

: "${GARM_HOSTNAME:?required}"
: "${GARM_JWT_SECRET:?required}"
: "${GARM_DB_PASSPHRASE:?required}"
: "${GITHUB_TOKEN:?required}"
envsubst < /config.toml.tmpl > /etc/garm/config.toml

: "${SUBSCRIPTION_ID:?required}"
: "${AZURE_CLIENT_ID:?required}"
envsubst < /azure-config.toml.tmpl > /etc/garm/azure-config.toml

nohup /usr/bin/garm -config /etc/garm/config.toml & GARM_PID=$!
echo "garm_pid: $GARM_PID"

curl -sSf -X POST -H "Content-Type: application/json" http://localhost:9997/api/v1/first-run/ \
	--retry 3 \
	--retry-connrefused \
	-d@<(jq -n --arg pw "$GARM_ADMIN_PW" '{
		email:    "root@localhost",
		username: "admin",
		password: $pw,
	}') \
	> /dev/null
TOKEN=$(curl -sSf -X POST -H "Content-Type: application/json" http://localhost:9997/api/v1/auth/login \
	-d@<(jq -n --arg pw "$GARM_ADMIN_PW" '{
		username: "admin",
		password: $pw,
	}') \
	| jq -r '.token')
echo "token: ***"

REPOSITORY_ID=$(curl -sSf -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
	http://localhost:9997/api/v1/repositories \
	-d@<(jq -n --arg ws "$GITHUB_WEBHOOK_SECRET" '{
		credentials_name: "garm",
		owner:            "mkulke",
		name:             "garm-playground",
		webhook_secret:   $ws
	}') \
	| jq -r '.id')
echo "repository_id: $REPOSITORY_ID"

POOL_ID=$(curl -sSf -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN" \
	"http://localhost:9997/api/v1/repositories/$REPOSITORY_ID/pools" \
	-d@<(jq -n '{
		provider_name:   "azure_external",
		max_runners:     4,
		min_idle_runner: 0,
		image:           "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest",
		flavor:          "Standard_F2s_v2",
		tags:            ["self-hosted", "linux"],
		enabled:         true,
		os_type:         "linux",
		os_arch:         "amd64",
	}') \
	| jq -r '.id')
echo "pool_id: $POOL_ID"

kill "$GARM_PID"
