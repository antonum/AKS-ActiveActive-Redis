#!/bin/bash

# load configuration options from file
# change setting like cluster names, DNS zones etc in config.sh
source config.sh
echo "Using configuration in config.sh:"
cat config.sh

# get defined clusters in kube config
kubectl config get-clusters

# make sure helm repo fot HAProxy is present
# https://haproxy-ingress.github.io/docs/getting-started/
helm repo add haproxy-ingress https://haproxy-ingress.github.io/charts
helm repo update

# list AKS c luster
#az aks list | grep name 

# load credentials
#az aks get-credentials -g $RESOURCE_GROUP  --name $CLUSTER1 --context $CLUSTER1 --overwrite-existing
#az aks get-credentials -g $RESOURCE_GROUP  --name $CLUSTER2 --context $CLUSTER2 --overwrite-existing


# get defined clusters in kube config
#kubectl config get-clusters
az aks get-credentials -g $RESOURCE_GROUP  --name $CLUSTER1 --context $CLUSTER1 --overwrite-existing
az aks get-credentials -g $RESOURCE_GROUP  --name $CLUSTER2 --context $CLUSTER2 --overwrite-existing

for CLUSTER in $CLUSTER1 $CLUSTER2
do

echo "switching to $CLUSTER"
kubectl config use-context $CLUSTER
kubectl create ns $NS

# install ingress controller
#kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
#kubectl apply -f haproxy.yaml
#helm repo add haproxytech https://haproxytech.github.io/helm-charts
#helm repo update
#helm install haproxy-kubernetes-ingress haproxytech/kubernetes-ingress     --create-namespace     --namespace haproxy-controller     --set controller.service.type=LoadBalancer

helm install haproxy-ingress haproxy-ingress/haproxy-ingress\
  --create-namespace --namespace ingress-controller\
  --version 0.14.4\
  -f templates/haproxy-ingress-values.yaml

# Install Redis operator and configure Redis Enterprise Cluster
kubectl apply -n $NS -f https://raw.githubusercontent.com/RedisLabs/redis-enterprise-k8s-docs/master/bundle.yaml
kubectl apply -n $NS -f - << EOF   
apiVersion: app.redislabs.com/v1
kind: RedisEnterpriseCluster
metadata:
  name: rec-$CLUSTER
spec:
  # Add fields here
  nodes: 3
  redisEnterpriseNodeResources:
    limits:
      cpu: 1000m
      memory: 4Gi
    requests:
      cpu: 1000m
      memory: 4Gi
EOF

#todo: need better "try while not avaliable logic here"
echo "Waiting for REC and ingress service/public IP creation..."
sleep 10

#get public IP of ingress controller
#CLUSTER_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o json | jq -r '.status.loadBalancer.ingress | .[0].ip')
CLUSTER_IP=$(kubectl get svc -n ingress-controller  haproxy-ingress -o json | jq -r '.status.loadBalancer.ingress | .[0].ip')
echo "Cluster $CLUSTER Public IP: $CLUSTER_IP"

# delete existing DNS records if any 
az network dns record-set a delete -g $DNS_RESOURCE_GROUP -z $DNS_ZONE -n "*.$CLUSTER" -y

# create A record 
# TTL set very low for debug create/destroy cycle. can be omitted (default 3600) in prod
az network dns record-set a add-record -g $DNS_RESOURCE_GROUP -z $DNS_ZONE -n "*.$CLUSTER" -a $CLUSTER_IP #--ttl 10

kubectl -n $NS get secret admission-tls
CERT=`kubectl -n $NS get secret admission-tls -o jsonpath='{.data.cert}'`
#cp templates/webhook.yaml webhook.yaml
sed "s/NAMESPACE/$NS/g" templates/webhook.yaml > tmp.yaml
sed "s/CERT/$CERT/g" tmp.yaml > webhook.yaml
rm tmp.yaml
kubectl -n $NS apply -f webhook.yaml

#kubectl -n $NS patch rec  rec-$CLUSTER --type merge --patch "{\"spec\": \
#    {\"ingressOrRouteSpec\": \
#      {\"apiFqdnUrl\": \"api.$CLUSTER.$DNS_ZONE\", \
#      \"dbFqdnSuffix\": \"-db.$CLUSTER.$DNS_ZONE\", \
#      \"ingressAnnotations\": {\"kubernetes.io/ingress.class\": \"nginx\", \
#      \"nginx.ingress.kubernetes.io/backend-protocol\": \"HTTPS\", \
#      \"nginx.ingress.kubernetes.io/ssl-passthrough\": \"true\"}, \
#      \"method\": \"ingress\"}}}"

#kubectl -n $NS patch rec  rec-$CLUSTER --type merge --patch "{\"spec\": \
#    {\"activeActive\": \
#      {\"apiIngressUrl\": \"api.$CLUSTER.$DNS_ZONE\", \
#      \"dbIngressSuffix\": \"-db.$CLUSTER.$DNS_ZONE\", \
#      \"ingressAnnotations\": {\"kubernetes.io/ingress.class\": \"nginx\", \
#      \"nginx.ingress.kubernetes.io/backend-protocol\": \"HTTPS\", \
#      \"nginx.ingress.kubernetes.io/ssl-passthrough\": \"true\"}, \
#      \"method\": \"ingress\"}}}"

# HAProxy crdb-cli
#kubectl -n $NS patch rec  rec-$CLUSTER --type merge --patch "{\"spec\": \
#    {\"activeActive\": \
#      {\"apiIngressUrl\": \"api.$CLUSTER.$DNS_ZONE\", \
#      \"dbIngressSuffix\": \"-db.$CLUSTER.$DNS_ZONE\", \
#      \"ingressAnnotations\": {\"kubernetes.io/ingress.class\": \"haproxy\", \
#      \"haproxy-ingress.github.io/ssl-passthrough\": \"true\"}, \
#      \"method\": \"ingress\"}}}"

# HAProxy RERC
kubectl -n $NS patch rec  rec-$CLUSTER --type merge --patch "{\"spec\": \
    {\"ingressOrRouteSpec\": \
      {\"apiFqdnUrl\": \"api.$CLUSTER.$DNS_ZONE\", \
      \"dbFqdnSuffix\": \"-db.$CLUSTER.$DNS_ZONE\", \
      \"ingressAnnotations\": {\"kubernetes.io/ingress.class\": \"haproxy\", \
      \"haproxy-ingress.github.io/ssl-passthrough\": \"true\"}, \
      \"method\": \"ingress\"}}}"

#activeActive:
#  apiIngressUrl: <api-hostname>
#  dbIngressSuffix: <ingress-suffix>
#  ingressAnnotations:
#     kubernetes.io/ingress.class: nginx
#    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
#    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
#  method: ingress

done

# Set the desired status
desired_status="Running"

# Loop until the desired status is reached
while [ "$kubectl_output" != "$desired_status" ]; do
    kubectl_output=$(kubectl get rec rec-redis-canadacentral -n rec -o json | jq -r .status.state)
    echo "Current status: $kubectl_output"
    
    sleep 5  # Adjust the sleep duration as needed
done

echo "Status is now $desired_status"
#exit 0
