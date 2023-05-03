# Garm Playground

Deploying GARM for self-hosted azure workers

## Build

```bash
docker build -t garm-azure .
```

## Run

The container carries a bootstrap script which is supposed to be called from a sidecar later. refer to the init + bootstrap script to see the envs that need to be populated for the container.

### Service

```bash
docker run -p 9997:9997 -it --init \
	--name garm-azure \
	--env-file config.env \
	--env-file secrets.env \
	garm-azure
```

### Bootstrap

```bash
docker exec -it garm-azure /bootstrap.sh
```

## Webhook

To react to github workflow events, you need to expose the 9997 port of the container as an https endpoint on the internet. Tailscale Funnel is a convenient way to test this locally.
