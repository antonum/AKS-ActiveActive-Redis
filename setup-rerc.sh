# load configuration options from file
# change setting like cluster names, DNS zones etc in config.sh
source config.sh
echo "Using configuration in config.sh:"
cat config.sh

# cleaning up ./yaml directory
rm ./yaml/*.yaml

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

# create secret
tee yaml/secret-$CLUSTER.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: redis-enterprise-$CLUSTER
type: Opaque
data:
  password: $B64_PASSWORD
  username: $B64_USERNAME

EOF

# create Redis Enterprise Remote Cluster
tee yaml/rerc-$CLUSTER.yaml <<EOF
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseRemoteCluster
metadata:
  name: $CLUSTER
spec:
  recName: rec-$CLUSTER
  recNamespace: $NS
  apiFqdnUrl: api.$CLUSTER.$DNS_ZONE
  dbFqdnSuffix: -db.$CLUSTER.$DNS_ZONE
  secretName: redis-enterprise-$CLUSTER

EOF

done

echo "Applying generated yaml files"

for CLUSTER in $CLUSTER1 $CLUSTER2
do
echo "switching to $CLUSTER"
kubectl config use-context $CLUSTER
kubectl -n $NS apply -f ./yaml/
done

tee yaml/crdb.yaml <<EOF
apiVersion: app.redislabs.com/v1alpha1
kind: RedisEnterpriseActiveActiveDatabase
metadata:
  name: crdb-anton
spec:
  globalConfigurations:
    #databaseSecretName: crdb-anton
    memorySize: 200MB
    shardCount: 1
    replication: true
    persistence: "aofEverySecond"
  participatingClusters:
      - name: $CLUSTER1
      - name: $CLUSTER2

EOF

echo "Active-Active database yaml is generated at: yaml/crdb.yaml"
echo "to activate on any of the clusters run: "
echo "kubectl apply -n $NS -f yaml/crdb.yaml"