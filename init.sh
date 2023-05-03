#!/bin/bash

set -euo pipefail

: ${GARM_HOSTNAME:?"required"}
: ${GARM_JWT_SECRET:?"required"}
: ${GARM_DB_PASSPHRASE:?"required"}
: ${GITHUB_TOKEN:?"required"}

envsubst < /etc/garm/config.toml.tmpl > /etc/garm/config.toml

: ${SUBSCRIPTION_ID:?"required"}
: ${AZURE_CLIENT_ID:?"required"}
: ${AZURE_TENANT_ID:?"required"}
: ${AZURE_CLIENT_SECRET:?"required"}

envsubst < /etc/garm/azure-config.toml.tmpl > /etc/garm/azure-config.toml

/usr/bin/garm -config /etc/garm/config.toml
