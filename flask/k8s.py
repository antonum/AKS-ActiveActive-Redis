from kubernetes import client, config
from pprint import pprint
import base64
from requests.auth import HTTPBasicAuth
import requests
import json

region="eastus"

##region="canadacentral" 

config.load_kube_config(context=f"redis-{region}")

v1 = client.CoreV1Api()
secret=v1.read_namespaced_secret(f"rec-redis-{region}", "rec")
user=base64.b64decode(secret.data['username'])
pwd=base64.b64decode(secret.data['password'])
basic = HTTPBasicAuth(user.decode('utf-8'), pwd.decode('utf-8'))

r=requests.get(f"https://api.redis-{region}.demo.umnikov.com/v1/nodes", auth=basic, verify=False)
for node in json.loads(r.text):
    print(node['status'])
    print(node['uid'])
    #pprint(node)
 
r=requests.get(f"https://api.redis-{region}.demo.umnikov.com/v1/shards", auth=basic, verify=False)
for shard in json.loads(r.text):
    print(shard['status'])
    print(shard['role'])
    print(shard['node_uid'])
    print(shard['bdb_uid'])
    print(shard['detailed_status'])

    pprint(shard)

rec=client.CustomObjectsApi().get_namespaced_custom_object(
    namespace="rec", 
    group="app.redislabs.com", 
    version="v1", 
    #pretty=True,
    name=f"rec-redis-{region}",
    plural="redisenterpriseclusters"
    )
#pprint(rec["status"])


rec=client.CustomObjectsApi().get_namespaced_custom_object(
    namespace="rec", 
    group="app.redislabs.com", 
    version="v1alpha1", 
    #pretty=True,
    name="crdb-anton",
    plural="redisenterpriseactiveactivedatabases"
    )
#pprint(rec["status"])