
import redis
import ssl
import datetime

# https://github.com/redis/redis-py/blob/master/docs/examples/ssl_connection_examples.ipynb

region1="canadacentral"
region2="eastus"
dns_suffix="sademo.umnikov.com"

redis1 = redis.StrictRedis(
    host=f"crdb-anton-db.redis-{region1}.{dns_suffix}",
    port=443, db=0, 
    ssl=True,
    ssl_cert_reqs=None,
    )

redis2 = redis.StrictRedis(
    host=f"crdb-anton-db.redis-{region2}.{dns_suffix}",
    port=443, db=0, 
    ssl=True,
    ssl_cert_reqs=None,
    )

print(f"### Basic ping test ###")
print(redis1.ping())
print(redis2.ping())

niter=100
r1=[]
r2=[]
print(f"### Ping test for {niter} iterations###")
for i in range(niter):
    r1_start=datetime.datetime.now()
    redis1.ping()
    r1_end=datetime.datetime.now()
    r1.append((r1_end-r1_start).microseconds)

    r2_start=datetime.datetime.now()
    redis2.ping()
    r2_end=datetime.datetime.now()
    r2.append((r2_end-r2_start).microseconds)

print(f"Avg PING for Redis {region1}:", sum(r1) / len(r1))
print(f"Avg PING for Redis {region2}:", sum(r2) / len(r2))
#print(r1,r2)