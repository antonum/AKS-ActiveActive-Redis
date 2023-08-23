from flask import Flask, jsonify, render_template
from kubernetes import client, config
import redis
import time
import base64
from requests.auth import HTTPBasicAuth
import requests
import json

app = Flask(__name__)


region1="canadacentral"
region2="eastus"
dns_suffix="demo.umnikov.com"

def connect_to_redis(region):
    try:
        r = redis.StrictRedis(
            host=f"crdb-anton-db.redis-{region}.{dns_suffix}",
            port=443, db=0, 
            ssl=True,
            ssl_cert_reqs=None,
            decode_responses=True,
            socket_timeout=1
            
        )
        r.ping()  # Check if the connection is alive
        return r
    except redis.ConnectionError as e:
        return None
    except redis.TimeoutError as e:
        return None
        
@app.route('/redis1')
def redis1():
    redis_connection = connect_to_redis(f"{region1}")
    if redis_connection:
        return jsonify(message="Connected to Redis successfully")
    else:
        return jsonify(message="Error: Redis is not available")
    
@app.route('/redis2')
def redis2():
    redis_connection = connect_to_redis(region2)
    if redis_connection:
        return jsonify(message="Connected to Redis successfully")
    else:
        return jsonify(message="Error: Redis is not available")

@app.route('/redis12')
def redis12():
    redis_connection1 = connect_to_redis(f"{region1}")
    redis_connection2 = connect_to_redis(f"{region2}")
    if redis_connection1:
        return jsonify(message=f"Connected to Redis {region1} successfully")
    elif redis_connection2:
        return jsonify(message=f"Connected to Redis {region2} successfully")
    else:
        return jsonify(message="Error: Redis is not available in both regions")
    

def get_cluster(region):
    try:
        config.load_kube_config(context=f"redis-{region}")
        v1 = client.CoreV1Api()
        secret=v1.read_namespaced_secret(f"rec-redis-{region}", "rec")
        user=base64.b64decode(secret.data['username'])
        pwd=base64.b64decode(secret.data['password'])
        basic = HTTPBasicAuth(user.decode('utf-8'), pwd.decode('utf-8'))
    except:
        return jsonify(message="Error: Can not connect to Kubernetes cluster")

    try:
        r=requests.get(f"https://api.redis-{region}.demo.umnikov.com/v1/nodes", auth=basic, verify=False, timeout=2)
    except:
        return jsonify(message="Error: Can not connect to Redis Enterprise cluster")
    res={}
    for node in json.loads(r.text):
        node_small={}
        node_small['status']=node['status']
        node_small['uid']=node['uid']
        node_small['shards']=[]
        res[f"node_{node['uid']}"]=node_small

    r=requests.get(f"https://api.redis-{region}.demo.umnikov.com/v1/shards", auth=basic, verify=False)
    for shard in json.loads(r.text):
        shard_small={}
        shard_small['status']=shard['status']
        role=shard['role']
        if role=="master":
            role="primary"        
        if role=="slave":
            role="replica"
        shard_small['role']=role
        shard_small['bdb_uid']=shard['bdb_uid']
        shard_small['detailed_status']=shard['detailed_status']
        res[f"node_{shard['node_uid']}"]['shards'].append(shard_small)
    return res

@app.route('/cluster1')
def cluster1():
    return get_cluster(region1)

@app.route('/cluster2')
def cluster2():
    return get_cluster(region2)

@app.route('/')
def index():
    return render_template('index.html')

if __name__ == '__main__':
    while False:
        redis_conn = connect_to_redis(region1)
        if redis_conn:
            break
        else:
            print("Redis is not available. Retrying in 5 seconds...")
            time.sleep(5)
    
    app.run(debug=True)
