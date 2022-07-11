@description('The name of the App Service plan to create.')
param appServicePlanName string = 'shir-plan'

@description('The location into which the Azure resources should be deployed.')
param location string

@description('The name of the App Service application to create. This must be globally unique.')
param appName string

@description('The resource ID of the subnet to use for outbound connections.')
param appOutboundSubnetResourceId string

@description('The name of the SKU to use when creating the virtual machine.')
param appServicePlanSku object

@description('The instrumentation key of the Application Insights resource to send telemetry to.')
param applicationInsightsInstrumentationKey string

@description('The connection string for the Application Insights resource to send telemetry to.')
param applicationInsightsConnectionString string

@description('The name of the container registry that has the container image.')
param containerRegistryName string

@description('The repository name of the container image within the registry.')
param containerImageName string

@description('The tag of the container image within the registry.')
param containerImageTag string

@description('The name of the data factory that the self-hosted integration runtime should connect to.')
param dataFactoryName string

@description('The name of the self-hosted integration runtime that the container should connect to.')
param dataFactoryIntegrationRuntimeName string

@description('The name of the node to create for the self-hosted integration runtime.')
param dataFactoryIntegrationRuntimeNodeName string = 'AppServiceContainer'

var managedIdentityName = 'SampleApp'

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' existing = {
  name: containerRegistryName
}

var containerRegistryHostName = '${containerRegistryName}.azurecr.io'
var appWindowsFxVersion = 'DOCKER|${containerRegistryHostName}/${containerImageName}:${containerImageTag}'

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName

  resource integrationRuntime 'integrationRuntimes' existing = {
    name: dataFactoryIntegrationRuntimeName
  }
}

var dataFactoryAuthKey = dataFactory::integrationRuntime.listAuthKeys().authKey1

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: appServicePlanName
  location: location
  sku: appServicePlanSku
  properties: {
    hyperV: true
  }
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: managedIdentityName
  location: location
}

module appAcrRoleAssignment 'acr-role-assignment.bicep' = {
  name: 'app-acr-role-assignment'
  params: {
    containerRegistryName: containerRegistryName
    principalId: managedIdentity.properties.principalId
  }
}

resource app 'Microsoft.Web/sites@2021-03-01' = {
  name: appName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: appOutboundSubnetResourceId
    siteConfig: {
      alwaysOn: true
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsightsInstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'Recommended'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Java'
          value: '1'
        }
        {
          // The URL for the container registry.
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistryHostName}'
        }
        {
          // The username to use when accessing the container registry.
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: containerRegistry.listCredentials().username
        }
        {
          // The password to use when accessing the container registry.
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          // Disable persistent storage because we don't need it.
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          // Disable container availability checks, because this runs as a background process.
          name: 'CONTAINER_AVAILABILITY_CHECK_MODE'
          value: 'Off'
        }
        {
          // The authentication key to use when connecting to Azure Data Factory.
          name: 'AUTH_KEY'
          value: dataFactoryAuthKey
        }
        {
          // The name of the node to create for the self-hosted integration runtime.
          name: 'NODE_NAME'
          value: dataFactoryIntegrationRuntimeNodeName
        }
      ]
      // Use a user-assigned managed identity to connect to the container registry. (We still need the DOCKER_REGISTRY_SERVER_* settings in the appSettings array, though.)
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: managedIdentity.properties.clientId

      // The container image to deploy.
      windowsFxVersion: appWindowsFxVersion
    }
  }
  dependsOn: [
    appAcrRoleAssignment // Wait for the role assignment so the app can pull from the container registry.
  ]
}
