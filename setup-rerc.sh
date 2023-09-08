#!/bin/bash

# load configuration options from file
# change setting like cluster names, DNS zones etc in config.sh
source config.sh
echo "Using configuration in config.sh:"
cat config.sh

# cleaning up ./yaml directory
#rm ./yaml/*.yaml

for CLUSTER in $CLUSTER1 $CLUSTER2
do

echo "switching to $CLUSTER"
kubectl config use-context $CLUSTER
B64_USERNAME=$(kubectl -n $NS get secret -o json rec-$CLUSTER | jq .data.username) 
B64_PASSWORD=$(kubectl -n $NS get secret -o json rec-$CLUSTER | jq .data.password)

REC_UNAME=$(kubectl -n $NS get secret rec-$CLUSTER -o jsonpath='{.data.username}' | base64 --decode)
echo $REC_UNAME
REC_PASSWORD=$(kubectl -n $NS get secret rec-$CLUSTER -o jsonpath='{.data.password}' | base64 --decode)
echo $REC_PASSWORD

curl https://api.$CLUSTER.demo.umnikov.com:443/v1/cluster --insecure --connect-timeout 3\
  -H "content-type: application/json" \
  -u "$REC_UNAME:$REC_PASSWORD" \
  | jq .name

# create Redis Enterprise Remote Cluster Secret from template in templates folder
sed "s/CLUSTER/$CLUSTER/g" templates/rerc-secret.yaml > tmp.yaml
sed "s/B64_PASSWORD/$B64_PASSWORD/g" tmp.yaml > tmp1.yaml
sed "s/B64_USERNAME/$B64_USERNAME/g" tmp1.yaml > yaml/secret-$CLUSTER.yaml
rm tmp.yaml
rm tmp1.yaml


# create Redis Enterprise Remote Cluster template in templates folder
sed "s/DNS_ZONE/$DNS_ZONE/g" templates/rerc.yaml > tmp.yaml
sed "s/NAMESPACE/$NS/g" tmp.yaml > tmp1.yaml
sed "s/CLUSTER/$CLUSTER/g" tmp1.yaml > yaml/rerc-$CLUSTER.yaml
rm tmp.yaml
rm tmp1.yaml

done

echo "Applying generated yaml files"

for CLUSTER in $CLUSTER1 $CLUSTER2
do
echo "switching to $CLUSTER"
kubectl config use-context $CLUSTER
kubectl -n $NS apply -f yaml/secret-$CLUSTER1.yaml
kubectl -n $NS apply -f yaml/secret-$CLUSTER2.yaml
kubectl -n $NS apply -f yaml/rerc-$CLUSTER1.yaml
kubectl -n $NS apply -f yaml/rerc-$CLUSTER2.yaml
done


# create Redis Enterprise Remote Cluster template in templates folder
sed "s/NAMESPACE/$NS/g" templates/reaadb.yaml > tmp.yaml
sed "s/CLUSTER1/$CLUSTER1/g" tmp.yaml > tmp1.yaml
sed "s/CLUSTER2/$CLUSTER2/g" tmp1.yaml > yaml/reaadb.yaml
rm tmp.yaml
rm tmp1.yaml


echo "Active-Active database yaml is generated at: yaml/reaadb.yaml"
echo "to activate on any of the clusters run: "
echo "kubectl apply -n $NS -f yaml/reaadb.yaml"