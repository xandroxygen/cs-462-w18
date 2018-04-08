import picosapi as picos
import pytest
from time import sleep
import random
from pprint import pprint

# -----------------
# Define Base Stuff
# -----------------

base_url = "http://localhost:8080"
picos.set_config("Host", "localhost")
picos.set_config("Port", "8080")
sensors = [
    "Ag1v6uoBcsatNQLocPi6pu",
    "5ch5eBSthGHKozqppRkGoE",
    "5E2BXzMVFpbqh95HWe8e39",
    "VH7fWwCpjUSTi7eQkhxmmE",
    "A4fEY8c3zweRWZcsyVxRYo"
]

# -----
# Helpers
# -----


def add_temp_reading(eci, temp=None):
    temp = temp if temp is not None else float(
        format(random.uniform(10.0, 18.0), '.2f'))
    heartbeat_url = picos.event_url(
        eci, "temp-reading", "wovyn", "new_temperature_reading")
    return picos.post(heartbeat_url, data={
        "temperature": temp, "timestamp": "now/test"})


def gossip_init(eci):
    url = picos.event_url(eci, "init", "gossip", "init")
    return picos.post(url)


def gossip_stop(eci):
    url = picos.event_url(eci, "stop", "gossip", "process")
    return picos.post(url, data={"status": "off"})


def gossip_resume(eci):
    url = picos.event_url(eci, "stop", "gossip", "process")
    return picos.post(url, data={"status": "on"})


def start():
    for eci in sensors:
        gossip_init(eci)
    add_readings()


def add_readings():
    for eci in sensors:
        add_temp_reading(eci)


def stop_one():
    gossip_stop(sensors[1])


def resume_one():
    gossip_resume(sensors[1])


def stop():
    for eci in sensors:
        gossip_stop(eci)
