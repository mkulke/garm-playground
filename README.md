# Garm Playground

Deploying GARM for self-hosted azure workers. It listens to webhooks from Github to create VMs as self-hosted runners on demand.

## Build

```bash
docker build -t garm-azure .
```

## Service

The application is deployed as an [ACI](https://azure.microsoft.com/en-us/products/container-instances) Container Group. It is bootstrapped with an init container which creates an admin user, an initial repository registration, and a pool for the repository.

### Requirements

- A Resource Group
- A user assigned identity, which has role assignments that allow read/write operation for VM, Network resources and Resource Groups. The managed `Contributor` Role is able to do that, but you can apply more granular definitions. The resource needs to created in the resource group
- A Storage Account holding to holding the state of the application via file shares.
- A Key Vault keeping application secrets, refer to `parameters.json` for a list.

### Deployment

```bash
make deploy
...
garm-123abc.eastus.azurecontainer.io
```

## Webhook

To react to github workflow events, you need to expose the 9997 port of the container as an https endpoint on the internet. The application listens on `/webhooks`. Add a Webhook (e.g. `https://garm-dc6512.eastus.azurecontainer.io/webhooks`) to which `Workflow jobs` events are sent. If the `runs-on` labels of a job match a pool, the applications attempts to spawn a self-hosted runner.
