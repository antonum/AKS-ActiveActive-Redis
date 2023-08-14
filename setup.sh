RESOURCE_GROUP=anton-rg-aa-aks
CLUSTER1=redis-eastus
CLUSTER2=redis-canadacentral
DNS_ZONE=demo.umnikov.com
# Resource Group zone where DNS is defined
DNS_RESOURCE_GROUP=anton-rg
NS=rec

# get defined clusters in kube config
kubectl config get-clusters

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
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

#todo: need better "try while not avaliable logic here"
echo "Waiting for ingress service/public IP creation..."
sleep 20

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
      cpu: 2000m
      memory: 8Gi
    requests:
      cpu: 2000m
      memory: 8Gi
EOF

#get public IP of ingress controller
CLUSTER_IP=$(kubectl get svc ingress-nginx-controller -n ingress-nginx -o json | jq -r '.status.loadBalancer.ingress | .[0].ip')
echo "Cluster $CLUSTER Public IP: $CLUSTER_IP"

# delete existing DNS records if any 
az network dns record-set a delete -g $DNS_RESOURCE_GROUP -z $DNS_ZONE -n "*.$CLUSTER" -y

#create A record 
az network dns record-set a add-record -g $DNS_RESOURCE_GROUP -z $DNS_ZONE -n "*.$CLUSTER" -a $CLUSTER_IP

kubectl -n $NS get secret admission-tls
CERT=`kubectl -n $NS get secret admission-tls -o jsonpath='{.data.cert}'`

kubectl -n $NS patch rec  rec-$CLUSTER --type merge --patch "{\"spec\": \
    {\"ingressOrRouteSpec\": \
      {\"apiFqdnUrl\": \"api.$CLUSTER.$DNS_ZONE\", \
      \"dbFqdnSuffix\": \"-db.$CLUSTER.$DNS_ZONE\", \
      \"ingressAnnotations\": {\"kubernetes.io/ingress.class\": \"nginx\", \
      \"nginx.ingress.kubernetes.io/backend-protocol\": \"HTTPS\", \
      \"nginx.ingress.kubernetes.io/ssl-passthrough\": \"true\"}, \
      \"method\": \"ingress\"}}}"

done


