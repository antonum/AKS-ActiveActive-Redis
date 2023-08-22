from flask import Flask, jsonify, render_template
import redis
import time

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
