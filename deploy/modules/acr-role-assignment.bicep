@description('The name of the container registry that the principal should be granted access to.')
param containerRegistryName string

@description('The Azure AD object ID to grant AcrPull access to.')
param principalId string

@description('This is the built-in AcrPull role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#acrpull')
resource acrPullRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: subscription()
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' existing = {
  name: containerRegistryName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, principalId, acrPullRoleDefinition.id)
  properties: {
    roleDefinitionId: acrPullRoleDefinition.id
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
