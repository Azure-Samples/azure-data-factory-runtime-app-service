@description('The name of the data factory that this pipeline should be added to.')
param dataFactoryName string

@description('The resource name of the self-hosted integration runtime that should be used to run this pipeline\'s activities.')
param integrationRuntimeName string

@description('The private IP address of the virtual machine that contains the private web server, which the pipeline will access.')
param virtualMachinePrivateIPAddress string

var pipelineName = 'sample-pipeline'

resource dataFactory 'Microsoft.DataFactory/factories@2018-06-01' existing = {
  name: dataFactoryName

  resource integrationRuntime 'integrationRuntimes' existing = {
    name: integrationRuntimeName
  }
}

resource pipeline 'Microsoft.DataFactory/factories/pipelines@2018-06-01' = {
  parent: dataFactory
  name: pipelineName
  properties: {
    activities: [
      {
        name: 'GetWebContent'
        type: 'WebActivity'
        typeProperties: {
          url: 'http://${virtualMachinePrivateIPAddress}/'
          connectVia: {
            referenceName: dataFactory::integrationRuntime.name
            type: 'IntegrationRuntimeReference'
          }
          method: 'GET'
          disableCertValidation: true
        }
      }
    ] 
  }
}
