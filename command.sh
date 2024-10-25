sudo apt-get install -y curl
curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt-get install gitlab-runner

# Edit config.toml
sudo vi /etc/gitlab-runner/config.toml

gitlab-runner run
# Use the below command to get the password for our argoCD server.
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath={.data.password} | base64 -d ; echo

registry.gitlab.com/gyenoch1/microservice/currencyservice

kubectl get secret my-registry-secret -n hipstershop -o jsonpath="{.data.\.dockerconfigjson}" | base64 --decode



helm uninstall aws-load-balancer-controller -n kube-system
kubectl get all -n kube-system | grep aws-load-balancer-controller
kubectl get serviceaccount aws-load-balancer-controller -n kube-system
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
kubectl logs -n kube-system <aws-load-balancer-controller-pod-name>


kubectl -n kube-system logs deployment/cluster-autoscaler
kubectl get events -n kube-system --sort-by='.lastTimestamp'
kubectl get deployments -n kube-system
kubectl -n kube-system logs -f deployment/<correct-name>
kubectl get pods -n kube-system
kubectl describe pod cluster-autoscaler-aws-cluster-autoscaler-6f77589485-jwjwc -n kube-system
helm list -n kube-system
helm status cluster-autoscaler -n kube-system

https://gitlab.com/gyenoch1/microservice.git

kubectl get pods -n kube-system | grep cluster-autoscaler
kubectl describe pod cluster-autoscaler-aws-cluster-autoscaler-6f77589485-pfh26 -n kube-system

kubectl top pods
kubectl top nodes

kubectl delete deployment --all -n hipstershop
kubectl delete svc --all -n hipstershop
kubectl delete po --all -n hipstershop
kubectl delete statefulset redis -n hipstershop

kubectl exec -it frontend-7469fd4757-9fw9m -n hipstershop -- sh

helm uninstall microservice -n argocd

kubectl get applications -n argocd

kubectl delete application <application-name> -n argocd
kubectl delete application adservice -n argocd
kubectl delete application cartservice -n argocd
kubectl delete application checkoutservice -n argocd
# and so on for each application...

aws ec2 describe-subnets --filters "Name=vpc-id,Values=<your-vpc-id>" --query "Subnets[].[SubnetId,Tags]" --output text

kubectl annotate service frontend -n hipstershop "service.kubernetes.io/force-recreate=true"


kubectl describe serviceaccount aws-load-balancer-controller -n kube-system
kubectl describe clusterrole aws-load-balancer-controller
aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.resourcesVpcConfig.subnetIds"

curl "http://monitoring-kube-prometheus-prometheus.monitoring:80/api/v1/query?query=up"

https://hooks.slack.com/services/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


curl -X POST --data-urlencode "payload={\"channel\": \"success-group\", \"username\": \"webhookbot\", \"text\": \"This is posted to #my-channel-here and comes from a bot named webhookbot.\", \"icon_emoji\": \":ghost:\"}" $SLACK_URL <add-your-slack-url-here>
