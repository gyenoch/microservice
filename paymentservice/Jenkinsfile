#!groovy
@Library('hipstershop-shared-library') _

def configMap = [ // variable creation
    application: "nodejsEKS", // jenkins-shared-library nodejsEKS name
    component: "paymentservice"
]
// pipelineDecision.decidePipeline(configMap) // it is calling pipelineDecision.groovy

stage('calling nodejsEKS pipeline') { 
    // Call the nodejsEKS function from the shared library
    nodejsEKS(configMap)
}
