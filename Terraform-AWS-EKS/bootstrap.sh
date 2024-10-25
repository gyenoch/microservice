#!/bin/bash
set -e

# Source environment variables
if [ -f ".env" ]; then
  # Remove carriage returns and export environment variables
  export $(grep -v '^#' .env | tr -d '\r' | xargs)
else
  echo ".env file not found!"
  exit 1
fi

echo $AWS_ACCESS_KEY_ID
echo $AWS_SECRET_ACCESS_KEY
echo $GITLAB_USERNAME
echo $GITLAB_TOKEN
echo $GITLAB_EMAIL

# Update server
sudo apt update 

# install necessary packages
# Function to check if a package is installed
is_installed() {
    dpkg -l "$1" &> /dev/null
}

# Check and install 'unzip' if not installed
if is_installed "unzip"; then
    echo "'unzip' is already installed."
else
    echo "'unzip' is not installed. Installing..."
    sudo apt install -y unzip || { echo "Failed to install 'unzip'"; exit 1; }
fi

# Check and install 'curl' if not installed
if is_installed "curl"; then
    echo "'curl' is already installed."
else
    echo "'curl' is not installed. Installing..."
    sudo apt install -y curl || { echo "Failed to install 'curl'"; exit 1; }
fi

# Check and install 'ca-certificates' if not installed
if is_installed "ca-certificates"; then
    echo "'ca-certificates' is already installed."
else
    echo "'ca-certificates' is not installed. Installing..."
    sudo apt install -y ca-certificates || { echo "Failed to install 'ca-certificates'"; exit 1; }
fi

# Install AWS CLI
if ! command -v aws &> /dev/null; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update || { echo "Failed to start Docker"; exit 1; }
fi

# Wait for AWS CLI to be available
while ! command -v aws &> /dev/null; do
  sleep 1
done

# Configure AWS CLI
aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set default.region us-east-1
aws configure set default.output json

# Install Kubectl
if ! command -v kubectl &> /dev/null; then
  curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.29.3/2024-04-19/bin/linux/amd64/kubectl
  chmod +x ./kubectl
  mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl
  echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc
  export PATH=$HOME/bin:$PATH
fi

# Install eksctl
# Set architecture and platform for eksctl download
ARCH=amd64  # Update if you're on an ARM system: use 'arm64', 'armv6', or 'armv7' as appropriate
PLATFORM=$(uname -s)_$ARCH

# Check if eksctl is installed, if not, download and install it
if ! command -v eksctl &> /dev/null; then
  echo "eksctl not found, installing..."
  
  # Download eksctl tar.gz for the detected platform
  curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
  
  # (Optional) Verify the checksum of the downloaded file
  curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check
  
  # Extract the eksctl binary and clean up the tar.gz file
  tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
  
  # Move eksctl to /usr/local/bin to make it available globally
  sudo mv /tmp/eksctl /usr/local/bin
  
  echo "eksctl installed successfully."
else
  echo "eksctl is already installed."
fi

# Wait for eksctl CLI to be available, in case it's not immediately found
while ! command -v eksctl &> /dev/null; do
  sleep 1
done

echo "eksctl is ready to use."

# Function to check if Docker is installed
check_docker_installed() {
    if docker --version &>/dev/null; then
        echo "Docker is already installed. Skipping installation."
        return 0
    else
        echo "Docker not found. Proceeding with installation..."
        return 1
    fi
}

# Install Docker if not already installed
if ! check_docker_installed; then
    echo "Installing Docker..."

    # Install required dependencies
    sudo apt-get -y install ca-certificates curl
    
    # Create the keyrings directory if it doesn't exist
    sudo install -m 0755 -d /etc/apt/keyrings
    
    # Download Docker GPG key
    if [ ! -f /etc/apt/keyrings/docker.asc ]; then
        echo "Downloading Docker's GPG key..."
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
    else
        echo "Docker's GPG key already exists. Skipping download."
    fi
    
    # Add Docker repository to apt sources if not already added
    if ! grep -q "^deb .*download.docker.com" /etc/apt/sources.list.d/docker.list 2>/dev/null; then
        echo "Adding Docker repository to apt sources..."
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    else
        echo "Docker repository already exists in apt sources. Skipping this step."
    fi
    
    # Update package list and install Docker packages
    echo "Updating package list and installing Docker..."
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Start and enable Docker
    sudo systemctl start docker || { echo "Failed to start Docker"; exit 1; }
    sudo systemctl enable docker
    
    # Set proper permissions on Docker socket
    sudo chmod 777 /var/run/docker.sock
    
    echo "Docker installation completed successfully."
else
    echo "Docker is already installed. No action needed."
fi

####################################################################################
# Check if the Docker container 'sonarqube' already exists
if [ "$(docker ps -a -q -f name=sonarqube)" ]; then
    echo "SonarQube container already exists. Stopping and removing it..."
    
    # Stop the container if it's running
    docker stop sonarqube || { echo "Failed to stop the SonarQube container"; exit 1; }
    
    # Remove the container
    docker rm sonarqube || { echo "Failed to remove the SonarQube container"; exit 1; }
else
    echo "No existing SonarQube container found. Proceeding to create a new one..."
fi

# Run a new SonarQube container
echo "Starting a new SonarQube container..."
docker run -d -p 9000:9000 --name sonarqube sonarqube:lts-community || { echo "Failed to start SonarQube container"; exit 1; }

echo "SonarQube container started successfully."

#########################################################################################################
# EKS CLUSTER SETUP
########################################################################################################
# Update kubeconfig to authenticate jump server with EKS cluster
aws eks update-kubeconfig --region us-east-1 --name mycluster || { echo "Failed to update kubeconfig"; exit 1; }

# Helm installation
if ! command -v helm &> /dev/null; then
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  chmod 700 get_helm.sh
  ./get_helm.sh
fi

sleep 5

#metrics server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
sleep 5

#################################################################################################################
# ARGOCD INSTALLATION
#################################################################################################################
# Check if namespace 'argocd' exists
if kubectl get namespace argocd &>/dev/null; then
    echo "Namespace 'argocd' already exists. Skipping creation."
else
    echo "Creating namespace 'argocd'..."
    kubectl create namespace argocd
fi

# Check if ArgoCD is already installed by checking the existence of its deployment
if kubectl get deployment -n argocd argocd-server &>/dev/null; then
    echo "ArgoCD is already installed in the 'argocd' namespace. Skipping installation."
else
    echo "Installing ArgoCD..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
fi

# Check if the argocd-server service is already of type LoadBalancer
SERVICE_TYPE=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.type}')
if [ "$SERVICE_TYPE" == "LoadBalancer" ]; then
    echo "Service 'argocd-server' is already of type LoadBalancer. Skipping patch."
else
    echo "Patching 'argocd-server' service to LoadBalancer type..."
    kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
fi

# Give some time for the patch to take effect
sleep 5

# Check if the 'argocd' CLI is already installed
if command -v argocd &>/dev/null; then
    echo "ArgoCD CLI is already installed. Skipping installation."
else
    echo "Installing ArgoCD CLI..."
    # Download and install the ArgoCD CLI
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
fi

sleep 5

#################################################################################################################
# Install Prometheus on EKS
#################################################################################################################
# Function to check if a Helm repo exists
check_helm_repo() {
    helm repo list | grep -w "$1" &>/dev/null
}

# Add stable Helm repo if it doesn't already exist
if check_helm_repo "stable"; then
    echo "Helm repo 'stable' already exists. Skipping addition."
else
    echo "Adding stable Helm repo..."
    helm repo add stable https://charts.helm.sh/stable
fi

# Add prometheus-community Helm repo if it doesn't already exist
if check_helm_repo "prometheus-community"; then
    echo "Helm repo 'prometheus-community' already exists. Skipping addition."
else
    echo "Adding prometheus-community Helm repo..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
fi

# Update Helm repos
echo "Updating Helm repos..."
helm repo update
sleep 5

# Check if the kube-prometheus-stack is already installed
if helm list -n monitoring | grep -w "monitoring" &>/dev/null; then
    echo "Kube Prometheus Stack is already installed. Skipping installation."
else
    echo "Installing Kube Prometheus Stack..."
    helm install monitoring prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
fi

# Check if the 'monitoring-kube-prometheus-prometheus' service is already of type LoadBalancer
PROMETHEUS_SERVICE_TYPE=$(kubectl get svc monitoring-kube-prometheus-prometheus -n monitoring -o jsonpath='{.spec.type}')
if [ "$PROMETHEUS_SERVICE_TYPE" == "LoadBalancer" ]; then
    echo "'monitoring-kube-prometheus-prometheus' service is already of type LoadBalancer. Skipping patch."
else
    echo "Patching 'monitoring-kube-prometheus-prometheus' service to LoadBalancer type..."
    kubectl patch svc monitoring-kube-prometheus-prometheus -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
fi

# Patch 'monitoring-kube-prometheus-prometheus' service to include ports 80 (external) and 9090 (internal)
echo "Patching 'monitoring-kube-prometheus-prometheus' service to use ports 80 and 9090..."
kubectl patch svc monitoring-kube-prometheus-prometheus -n monitoring --type='json' -p='[
    {
        "op": "replace",
        "path": "/spec/ports",
        "value": [
            {
                "name": "http-web",
                "port": 80,
                "targetPort": 9090,
                "protocol": "TCP"
            },
            {
                "name": "prometheus",
                "port": 9090,
                "targetPort": 9090,
                "protocol": "TCP"
            }
        ]
    }
]'

# Check if the 'monitoring-grafana' service is already of type LoadBalancer
GRAFANA_SERVICE_TYPE=$(kubectl get svc monitoring-grafana -n monitoring -o jsonpath='{.spec.type}')
if [ "$GRAFANA_SERVICE_TYPE" == "LoadBalancer" ]; then
    echo "'monitoring-grafana' service is already of type LoadBalancer. Skipping patch."
else
    echo "Patching 'monitoring-grafana' service to LoadBalancer type..."
    kubectl patch svc monitoring-grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
fi

# Give some time for services to update
sleep 5
################################################################################################
# Install Ingress controller
################################################################################################
# Variables (set these accordingly)
REGION="us-east-1"
CLUSTER_NAME="mycluster"
SERVICE_ACCOUNT_NAME="aws-load-balancer-controller"
NAMESPACE="kube-system"

# 1. Check if the IAM OIDC provider is already associated with the EKS cluster
OIDC_URL=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query "cluster.identity.oidc.issuer" --output text 2>/dev/null)

if [[ "$OIDC_URL" == "None" ]] || [[ -z "$OIDC_URL" ]]; then
    echo "No IAM OIDC provider found for cluster $CLUSTER_NAME. Creating one..."
    
    # Associate the IAM OIDC provider with the EKS cluster
    eksctl utils associate-iam-oidc-provider \
      --region "$REGION" \
      --cluster "$CLUSTER_NAME" \
      --approve

    if [ $? -eq 0 ]; then
        echo "IAM OIDC provider successfully associated with cluster $CLUSTER_NAME."
    else
        echo "Error associating IAM OIDC provider with cluster $CLUSTER_NAME."
        exit 1
    fi
else
    echo "IAM OIDC provider already exists for cluster $CLUSTER_NAME."
    echo "OIDC Provider URL: $OIDC_URL"
fi
sleep 5

# 2. Download an IAM policy for the LBC using one of the following commands
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.9.2/docs/install/iam_policy.json || { echo "Failed to download IAM policy"; exit 1; }

# 3. Create or recreate the IAM policy for AWS Load Balancer Controller
POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`AWSLoadBalancerControllerIAMPolicy`].Arn' --output text)

# Check if the policy exists
if [ -n "$POLICY_ARN" ]; then
  echo "Deleting existing IAM policy for AWS Load Balancer Controller: $POLICY_ARN"
  
  ATTACHED_ROLES=$(aws iam list-entities-for-policy --policy-arn "$POLICY_ARN" --query 'PolicyRoles[*].RoleName' --output text)

  # Detach the policy from any roles (if necessary)
  if [ -n "$ATTACHED_ROLES" ]; then
    echo "Detaching policy from roles: $ATTACHED_ROLES"
    for role in $ATTACHED_ROLES; do
      echo "Detaching policy from role: $role"
      aws iam detach-role-policy --role-name "$role" --policy-arn "$POLICY_ARN"
      
      # Delete the role after detaching the policy
      echo "Deleting role: $role"
      aws iam delete-role --role-name "$role" || { echo "Failed to delete role: $role"; exit 1; }
    done
  fi

  # Delete the existing policy
  aws iam delete-policy --policy-arn "$POLICY_ARN" || { echo "Failed to delete IAM policy"; exit 1; }
  echo "Existing IAM policy and roles deleted."
else
  echo "No existing IAM policy found. Proceeding to create a new one."
fi

# 5. Create a new policy
echo "Creating IAM policy for AWS Load Balancer Controller..."
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam-policy.json || { echo "Failed to create IAM policy"; exit 1; }
sleep 10

# 5.1 Re-fetch the new POLICY_ARN after the policy is created
POLICY_ARN=$(aws iam list-policies --query 'Policies[?PolicyName==`AWSLoadBalancerControllerIAMPolicy`].Arn' --output text)

# Check if the new policy ARN is fetched successfully
if [ -n "$POLICY_ARN" ]; then
    echo "Successfully fetched new IAM policy ARN: $POLICY_ARN"
else
    echo "Failed to fetch new IAM policy ARN."
    exit 1
fi
sleep 20

# 6. Check if the CloudFormation stack for the IAM service account exists and delete it if necessary
#Define the stack name
STACK_NAME="eksctl-$CLUSTER_NAME-addon-iamserviceaccount-$NAMESPACE-$SERVICE_ACCOUNT_NAME"

# Function to check if CloudFormation stack exists
check_stack_exists() {
  echo "Checking if CloudFormation stack $STACK_NAME exists..."

  # Run the describe-stacks command and capture the output and exit code
  if ! STACK_EXISTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" 2>&1); then
    # Check if the error is related to the stack not existing
    if echo "$STACK_EXISTS" | grep -q "ValidationError"; then
      echo "CloudFormation stack $STACK_NAME does not exist."
      return 1  # Return failure (1), meaning the stack does not exist
    else
      echo "An unexpected error occurred: $STACK_EXISTS"
      exit 1  # Exit if there's another error
    fi
  fi

  echo "CloudFormation stack $STACK_NAME exists."
  return 0  # Return success (0), meaning the stack exists
}

# Function to delete the CloudFormation stack
delete_stack() {
  echo "Deleting CloudFormation stack $STACK_NAME..."
  aws cloudformation delete-stack --stack-name "$STACK_NAME"

  # Wait until the stack deletion completes
  echo "Waiting for stack $STACK_NAME to be deleted..."
  aws cloudformation wait stack-delete-complete --stack-name "$STACK_NAME"
  
  if [ $? -eq 0 ]; then
      echo "CloudFormation stack $STACK_NAME deleted successfully."
  else
      echo "Error deleting CloudFormation stack $STACK_NAME."
      exit 1
  fi
}

# Check if the stack exists and delete only if it exists
if check_stack_exists; then
    delete_stack
else
    echo "No stack to delete, skipping deletion."
fi

# 7. Create a new IAM role and Kubernetes ServiceAccount for the AWS Load Balancer Controller
echo "Creating service account $SERVICE_ACCOUNT_NAME with IAM policy attached..."
eksctl create iamserviceaccount \
  --cluster="$CLUSTER_NAME" \
  --namespace="$NAMESPACE" \
  --name="$SERVICE_ACCOUNT_NAME" \
  --attach-policy-arn="$POLICY_ARN" \
  --override-existing-serviceaccounts \
  --region "$REGION" \
  --approve

if [ $? -eq 0 ]; then
    echo "Service account $SERVICE_ACCOUNT_NAME created successfully with IAM policy attached."
else
    echo "Failed to create service account $SERVICE_ACCOUNT_NAME."
    exit 1
fi

# 8. Install the AWS Load Balancer Controller using Helm
# Function to check if a Helm repo exists
check_helm_repo() {
    helm repo list | grep -w "$1" &>/dev/null
}

# Add eks Helm repo if it doesn't already exist
if check_helm_repo "eks"; then
    echo "Helm repo 'eks' already exists. Skipping addition."
else
    echo "Adding eks Helm repo..."
    helm repo add eks https://aws.github.io/eks-charts || { echo "Failed to add Helm repo"; exit 1; }
fi

# Update Helm repos
echo "Updating Helm repos..."
helm repo update

# Wait for the update to complete
sleep 5

# Check if AWS Load Balancer Controller is already installed in kube-system namespace
if helm list -n kube-system | grep -w "aws-load-balancer-controller" &>/dev/null; then
    echo "AWS Load Balancer Controller is already installed. Skipping installation."
else
    echo "Installing or upgrading AWS Load Balancer Controller..."
    helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
      --namespace kube-system \
      --set clusterName="$CLUSTER_NAME" \
      --set serviceAccount.create=false \
      --set serviceAccount.name="$SERVICE_ACCOUNT_NAME" \
      --set region="$REGION" || { echo "Failed to install/upgrade AWS Load Balancer Controller"; exit 1; }
fi

#####################################################################################################
# Check if a namespace exists
check_namespace() {
    kubectl get namespace "$1" &>/dev/null
}

# Check if a service account exists
check_service_account() {
    kubectl get serviceaccount "$1" -n "$2" &>/dev/null
}

# Check if a role exists
check_role() {
    kubectl get role "$1" -n "$2" &>/dev/null
}

# Check if a role binding exists
check_role_binding() {
    kubectl get rolebinding "$1" -n "$2" &>/dev/null
}

# Check if a secret exists
check_secret() {
    kubectl get secret "$1" -n "$2" &>/dev/null
}

# Variables (set these accordingly)
NAMESPACE="hipstershop"
SERVICE_ACCOUNT="my-service-account"
ROLE="my-role"
ROLE_BINDING="my-role-binding"
SECRET_NAME="my-registry-secret"

# Create namespace if it doesn't already exist
if check_namespace "$NAMESPACE"; then
    echo "Namespace '$NAMESPACE' already exists. Skipping creation."
else
    echo "Creating namespace '$NAMESPACE'..."
    kubectl create namespace "$NAMESPACE" || { echo "Failed to create namespace"; exit 1; }
fi

# Create service account if it doesn't already exist
if check_service_account "$SERVICE_ACCOUNT" "$NAMESPACE"; then
    echo "Service account '$SERVICE_ACCOUNT' already exists in namespace '$NAMESPACE'. Skipping creation."
else
    echo "Creating service account '$SERVICE_ACCOUNT'..."
    kubectl create serviceaccount "$SERVICE_ACCOUNT" --namespace "$NAMESPACE" || { echo "Failed to create service account"; exit 1; }
fi

# Create role if it doesn't already exist
if check_role "$ROLE" "$NAMESPACE"; then
    echo "Role '$ROLE' already exists in namespace '$NAMESPACE'. Skipping creation."
else
    echo "Creating role '$ROLE'..."
    kubectl create role "$ROLE" --namespace "$NAMESPACE" \
      --verb=get,list,create,update,patch,watch \
      --resource=pods,secrets,deployment,services || { echo "Failed to create role"; exit 1; }
fi

# Create role binding if it doesn't already exist
if check_role_binding "$ROLE_BINDING" "$NAMESPACE"; then
    echo "Role binding '$ROLE_BINDING' already exists in namespace '$NAMESPACE'. Skipping creation."
else
    echo "Creating role binding '$ROLE_BINDING'..."
    kubectl create rolebinding "$ROLE_BINDING" --role="$ROLE" --serviceaccount="$NAMESPACE:$SERVICE_ACCOUNT" || { echo "Failed to create role binding"; exit 1; }
fi

# Create secret if it doesn't already exist
if check_secret "$SECRET_NAME" "$NAMESPACE"; then
    echo "Secret '$SECRET_NAME' already exists in namespace '$NAMESPACE'. Skipping creation."
else
    echo "Creating Docker registry secret..."
    kubectl create secret docker-registry "$SECRET_NAME" \
      --docker-server=registry.gitlab.com \
      --docker-username="$GITLAB_USERNAME" \
      --docker-password="$GITLAB_TOKEN" \
      --docker-email="$GITLAB_EMAIL" \
      --namespace="$NAMESPACE" || { echo "Failed to create Docker registry secret"; exit 1; }
fi

##############################################################################################################
# Check if a Helm repo exists
check_helm_repo() {
    helm repo list | grep -w "$1" &>/dev/null
}

# Install Cluster Autoscaler Helm repo if it doesn't exist
if check_helm_repo "autoscaler"; then
    echo "Autoscaler Helm repo already exists. Skipping addition."
else
    echo "Adding Autoscaler Helm repo..."
    helm repo add autoscaler https://kubernetes.github.io/autoscaler || { echo "Failed to add Autoscaler repo"; exit 1; }
fi

# Update Helm repo
echo "Updating Helm repo..."
helm repo update || { echo "Failed to update Helm repos"; exit 1; }
sleep 10  # You can reduce this depending on repo update speed

# Wait for AWS Load Balancer Controller to be ready
echo "Waiting for AWS Load Balancer Controller to be ready..."
kubectl wait --namespace kube-system \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=aws-load-balancer-controller \
  --timeout=300s

# Check if waiting succeeded
if [ $? -eq 0 ]; then
    echo "AWS Load Balancer Controller is ready."
else
    echo "Error: AWS Load Balancer Controller not ready. Exiting."
    exit 1
fi

# Check if Cluster Autoscaler is already installed
if helm list -n kube-system | grep cluster-autoscaler; then
    echo "Cluster Autoscaler is already installed. Upgrading..."
else
    echo "Installing Cluster Autoscaler..."
fi

# Install or upgrade Cluster Autoscaler
helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set cloudProvider=aws \
  --set awsRegion="$REGION" \
  --set autoDiscovery.clusterName="$CLUSTER_NAME" \
  --set extraArgs.balance-similar-node-groups=true

# Check if the installation/upgrade was successful
if [ $? -eq 0 ]; then
    echo "Cluster Autoscaler installation/upgraded successfully."
else
    echo "Error: Failed to install/upgrade Cluster Autoscaler."
    exit 1
fi

echo "Script execution completed."
################################################################################################################################################