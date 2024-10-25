#!groovy
@Library('hipstershop-shared-library') _

def configMap = [ // variable creation
    application: "dotnetEKS", // jenkins-shared-library goEKS name
    component: "cartservice"
]
// pipelineDecision.decidePipeline(configMap) // it is calling pipelineDecision.groovy

stage('calling dotnetEKS pipeline') { 
    // Call the goEKS function from the shared library
    dotnetEKS(configMap)
}


