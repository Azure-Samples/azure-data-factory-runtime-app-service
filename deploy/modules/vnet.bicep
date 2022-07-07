@description('The name of the virtual network to create.')
param name string

@description('The location into which the Azure resources should be deployed.')
param location string

@description('The address prefix of the entire virtual network.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('The address prefix of the subnet for outbound communication from the application.')
param appOutboundSubnetAddressPrefix string = '10.0.0.0/24'

@description('The address prefix of the subnet for the data factory\'s private endpoint.')
param dataFactorySubnetAddressPrefix string = '10.0.1.0/24'

@description('The address prefix of the subnet for the virtual machine with the private web server.')
param vmSubnetAddressPrefix string = '10.0.2.0/24'

var appOutboundSubnetName = 'app-outbound'
var dataFactorySubnetName = 'data-factory'
var vmSubnetName = 'vm'

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: appOutboundSubnetName
        properties: {
          addressPrefix: appOutboundSubnetAddressPrefix
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverfarms'
              }
            }
          ]
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
          ]
        }
      }
      {
        name: dataFactorySubnetName
        properties: {
          addressPrefix: dataFactorySubnetAddressPrefix
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: vmSubnetName
        properties: {
          addressPrefix: vmSubnetAddressPrefix
        }
      }
    ]
  }

  resource appOutboundSubnet 'subnets' existing = {
    name: appOutboundSubnetName
  }

  resource dataFactorySubnet 'subnets' existing = {
    name: dataFactorySubnetName
  }

  resource vmSubnet 'subnets' existing = {
    name: vmSubnetName
  }
}

output virtualNetworkName string = virtualNetwork.name

output appOutboundSubnetResourceId string = virtualNetwork::appOutboundSubnet.id

output dataFactorySubnetResourceId string = virtualNetwork::dataFactorySubnet.id

output vmSubnetResourceId string = virtualNetwork::vmSubnet.id
