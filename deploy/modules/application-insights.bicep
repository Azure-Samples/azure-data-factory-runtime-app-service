@description('The name of the Application Insights resource to create.')
param name string = 'shir-app-insights'

@description('The location into which the Azure resources should be deployed.')
param location string

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

output instrumentationKey string = applicationInsights.properties.InstrumentationKey

output connectionString string = applicationInsights.properties.ConnectionString
