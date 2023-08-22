region=canadacentral
kubectl config use-context "redis-$region"
kubectl get nodes
az vmss list -o table
cluster=$(az vmss list -o table | grep $region)
rg=$(echo $cluster | awk '{print $2}')
vmss=$(echo $cluster | awk '{print $1}')
echo
echo "### Restart single cluster node in $region ###"

echo "az vmss restart " \
"--name $vmss" \
"--resource-group $rg" \
"--instance-ids 1" \
"--no-wait"
echo "watch kubectl get pods -n rec -o wide"

echo
echo "### Restart AKS cluster node in $region ###"

echo "az aks stop --name redis-$region --resource-group anton-rg-aa-aks --no-wait"
echo "sleep 30"
echo "az aks start --name redis-$region --resource-group anton-rg-aa-aks --no-wait"


echo
echo "### Recover from AKS cluster-wide outage ###"
echo "kubectl -n rec patch rec rec-redis-canadacentral --type merge --patch '{\"spec\":{\"clusterRecovery\":true}}'"
echo "watch \"kubectl -n rec describe rec | grep State\""

echo
echo "### Recover databases ###"
echo "kubectl exec -it  -n rec  rec-redis-$region-0 -- rladmin recover all"
