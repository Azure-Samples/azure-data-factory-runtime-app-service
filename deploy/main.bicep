@description('The location into which the Azure resources should be deployed.')
param location string = resourceGroup().location

@description('The name of the container registry to create. This must be globally unique.')
param containerRegistryName string = 'shir${uniqueString(resourceGroup().id)}'

@description('The name of the virtual network to create.')
param vnetName string = 'shirdemo'

@description('The name of the data factory to create. This must be globally unique.')
param dataFactoryName string = 'shirdemo${uniqueString(resourceGroup().id)}'

@description('The name of the App Service application to create. This must be globally unique.')
param appName string = 'app-${uniqueString(resourceGroup().id)}'

@description('The SKU of the App Service plan to run the self-hosted integration runtime container.')
param appServicePlanSku object = {
  name: 'P2v3'
  capacity: 1
}

@description('The name of the SKU to use when creating the virtual machine.')
param vmSize string = 'Standard_DS1_v2'

@description('The type of disk and storage account to use for the virtual machine\'s OS disk.')
param vmOSDiskStorageAccountType string = 'StandardSSD_LRS'

@description('The administrator username to use for the virtual machine.')
param vmAdminUsername string = 'shirdemoadmin'

@description('The administrator password to use for the virtual machine.')
@secure()
param vmAdminPassword string

// Deploy the container registry and build the container image.
module acr 'modules/acr.bicep' = {
  name: 'acr'
  params: {
    name: containerRegistryName
    location: location
  }
}

// Deploy a virtual network with the subnets required for this solution.
module vnet 'modules/vnet.bicep' = {
  name: 'vnet'
  params: {
    name: vnetName
    location: location
  }
}

// Deploy a virtual machine with a private web server.
var vmImageReference = {
  publisher: 'MicrosoftWindowsServer'
  offer: 'WindowsServer'
  sku: '2019-Datacenter'
  version: 'latest'
}

module vm 'modules/vm.bicep' = {
  name: 'vm'
  params: {
    location: location
    subnetResourceId: vnet.outputs.vmSubnetResourceId
    vmSize: vmSize
    vmImageReference: vmImageReference
    vmOSDiskStorageAccountType: vmOSDiskStorageAccountType
    vmAdminUsername: vmAdminUsername
    vmAdminPassword: vmAdminPassword
  }
}

// Deploy the data factory.
module adf 'modules/data-factory.bicep' = {
  name: 'adf'
  params: {
    dataFactoryName: dataFactoryName
    location: location
    virtualNetworkName: vnet.outputs.virtualNetworkName
    dataFactorySubnetResourceId: vnet.outputs.dataFactorySubnetResourceId
  }
}

// Deploy a Data Factory pipeline to connect to the private web server on the VM.
module dataFactoryPipeline 'modules/data-factory-pipeline.bicep' = {
  name: 'adf-pipeline'
  params: {
    dataFactoryName: adf.outputs.dataFactoryName
    integrationRuntimeName: adf.outputs.integrationRuntimeName
    virtualMachinePrivateIPAddress: vm.outputs.virtualMachinePrivateIPAddress
  }
}

// Deploy Application Insights, which the App Service app uses.
module applicationInsights 'modules/application-insights.bicep' = {
  name: 'application-insights'
  params: {
    location: location
  }
}

// Deploy the App Service app resources and deploy the container image from the container registry.
module app 'modules/app.bicep' = {
  name: 'app'
  params: {
    location: location
    appName: appName
    appOutboundSubnetResourceId: vnet.outputs.appOutboundSubnetResourceId
    applicationInsightsInstrumentationKey: applicationInsights.outputs.instrumentationKey
    applicationInsightsConnectionString: applicationInsights.outputs.connectionString
    containerRegistryName: acr.outputs.containerRegistryName
    containerImageName: acr.outputs.containerImageName
    containerImageTag: acr.outputs.containerImageTag
    dataFactoryName: adf.outputs.dataFactoryName
    dataFactoryIntegrationRuntimeName: adf.outputs.integrationRuntimeName
    appServicePlanSku: appServicePlanSku
  }
}
