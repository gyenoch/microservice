#!groovy
@Library('hipstershop-shared-library') _

def configMap = [ // variable creation
    application: "pythonEKS", // jenkins-shared-library goEKS name
    component: "recommendationservice"
]
// pipelineDecision.decidePipeline(configMap) // it is calling pipelineDecision.groovy

stage('calling pythonEKS pipeline') { 
    // Call the goEKS function from the shared library
    pythonEKS(configMap)
}


