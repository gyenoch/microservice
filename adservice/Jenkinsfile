#!groovy
@Library('hipstershop-shared-library') _

def configMap = [ // variable creation
    application: "gradleEKS", // jenkins-shared-library goEKS name
    component: "adservice"
]
// pipelineDecision.decidePipeline(configMap) // it is calling pipelineDecision.groovy

stage('calling gradleEKS pipeline') { 
    // Call the goEKS function from the shared library
    gradleEKS(configMap)
}


