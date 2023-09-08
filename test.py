
import redis
import ssl
import datetime

# https://github.com/redis/redis-py/blob/master/docs/examples/ssl_connection_examples.ipynb

region1="canadacentral"
region2="eastus"
dns_suffix="demo.umnikov.com"
#region2="canadaeast"
#dns_suffix="sademo.umnikov.com"



import random
import string

def randStr(chars = string.ascii_uppercase + string.digits, N=10):
	return ''.join(random.choice(chars) for _ in range(N))

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
print()

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

print(f"Avg PING for Redis {region1}:", sum(r1) / len(r1), " microseconds")
print(f"Avg PING for Redis {region2}:", sum(r2) / len(r2), " microseconds")
#print(r1,r2)
print()

niter=100
r1=[]
r2=[]
print(f"### ActiveActive sync test for {niter} iterations###")
for i in range(niter):
    r1_time=datetime.datetime.now().microsecond
    redis1.set(name=f"{region1}-aa", value=r1_time)
    #r1_aa_time=datetime.datetime.now().microsecond
    r1_aa_time=int(redis2.get(name=f"{region1}-aa"))
    if (r1_aa_time>r1_time):
         r1_time=r1_time+1000000

    print(r1_time, r1_aa_time, r1_time - r1_aa_time) 
    if (i>=1):
        r1.append(r1_time - r1_aa_time)
#print(r1,r2)
print(f"Avg AA Sync delay:", sum(r1) / len(r1), " microseconds")
print(f"Max AA Sync delay:", max(r1), " microseconds")
print(f"Min AA Sync delay:", min(r1), " microseconds")
print()


niter=10
payload_size=6000000
str=randStr(N=payload_size)
print(f"### Large payload for {niter} iterations###")
print(f"### Payload size {payload_size}###")
r1=[]
for i in range(niter):
    print(i)
    r1_start=datetime.datetime.now()
    redis1.set(name=f"{region1}", value=str)
    r1_end=datetime.datetime.now()
    r1.append((r1_end-r1_start).microseconds)

print(f"Avg SET for {payload_size} in {region1}:", sum(r1) / len(r1), " microseconds")
