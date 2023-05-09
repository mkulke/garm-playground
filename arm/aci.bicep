@description('Name for the container group')
param Name string

@description('Location for all resources.')
param Location string

@description('Storage Account Name for Caddy File Share')
param StorageAccount string

@description('DNS Name Label for the Public IP Address')
param DnsNameLabel string

@description('Image to use for the container')
param GarmImage string = 'ghcr.io/mkulke/garm:1.0'

@secure()
@description('JWT Secret for Garm')
param GarmJwtSecret string

@secure()
@description('DB Passphrase for Garm')
param GarmDbPassphrase string

@secure()
@description('Github Token for Garm')
param GithubToken string

@secure()
@description('Github Webhook Secret for the Repository')
param GithubWebhookSecret string

@secure()
@description('Admin Password for Garm')
param GarmAdminPw string

@description('Name of the User Assigned Identity')
param UserAssignedIdentityName string

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: UserAssignedIdentityName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' existing = {
  name: StorageAccount
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2021-02-01' = {
  parent: storageAccount
  name: 'default'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  parent: fileService
  name: Name
}

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: Name
  location: Location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    initContainers: [
      {
        name: 'garm-init'
        properties: {
          image: GarmImage
          environmentVariables: [
            {
              name: 'GARM_HOSTNAME'
              value: '${DnsNameLabel}.${Location}.azurecontainer.io'
            }
            {
              name: 'SUBSCRIPTION_ID'
              value: subscription().subscriptionId
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: userAssignedIdentity.properties.clientId
            }
            {
              name: 'GARM_JWT_SECRET'
              secureValue: GarmJwtSecret
            }
            {
              name: 'GARM_DB_PASSPHRASE'
              secureValue: GarmDbPassphrase
            }
            {
              name: 'GARM_ADMIN_PW'
              secureValue: GarmAdminPw
            }
            {
              name: 'GITHUB_TOKEN'
              secureValue: GithubToken
            }
            {
              name: 'GITHUB_WEBHOOK_SECRET'
              secureValue: GithubWebhookSecret
            }
          ]
          volumeMounts: [
            {
              name: 'share'
              mountPath: '/etc/garm'
            }
          ]
          command: [
            '/init.sh'
          ]
        }
      }
    ]
    containers: [
      {
        name: 'garm'
        properties: {
          image: GarmImage
          resources: {
            requests: {
              cpu: 1
              memoryInGB: json('0.5')
            }
          }
          volumeMounts: [
            {
              name: 'share'
              mountPath: '/etc/garm'
            }
          ]
          command: [
            'garm'
            '-config'
            '/etc/garm/config.toml'
          ]
        }
      }
      {
        name: 'caddy'
        properties: {
          image: 'caddy:2.6.4'
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
            {
              port: 443
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: json('0.5')
            }
          }
          volumeMounts: [
            {
              name: 'share'
              mountPath: '/data'
            }
          ]
          command: [
            'caddy'
            'reverse-proxy'
            '--from'
            '${DnsNameLabel}.${Location}.azurecontainer.io'
            '--to'
            'localhost:9997'
          ]
        }
      }
    ]
    osType: 'Linux'
    ipAddress: {
      type: 'Public'
      ports: [
        {
          port: 80
          protocol: 'TCP'
        }
        {
          port: 443
          protocol: 'TCP'
        }
      ]
      dnsNameLabel: DnsNameLabel
    }
    volumes: [
      {
        name: 'share'
        azureFile: {
          shareName: Name
          storageAccountName: storageAccount.name
          storageAccountKey: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
        }
      }
    ]
  }
}
