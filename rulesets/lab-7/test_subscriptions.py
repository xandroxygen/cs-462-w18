import picosapi as picos
import pytest
from time import sleep
import random

# -----------------
# Define Base Stuff
# -----------------

base_url = "http://localhost:8080"
manager_eci = "F5LBSZdjbJTFKpwHVKu8yC"
manager_pico_id = "xandroxygen.manage_sensors"
picos.set_config("Host", "localhost")
picos.set_config("Port", "8080")

# -----
# Tests
# -----


def cleanup():
    sleep(0.5)
    sensors = sensor_names()

    # delete subscriptions
    delete_subscriptions()

    # delete sensors
    sleep(0.5)
    url = picos.event_url(manager_eci, "unneeded_sensor",
                          "sensor", "unneeded_sensor")
    for name in sensors:
        picos.post(url, data={"name": name})


def delete_subscriptions():
    url = picos.event_url(manager_eci, "delete",
                          "sensor", "delete_subscriptions")
    ok, r = picos.post(url)
    if not ok:
        raise Exception("Call to `delete subscriptions` failed.")
    return r.content


def get(function_name):
    url = picos.api_url(manager_eci, manager_pico_id, function_name)
    ok, r = picos.get(url)
    if not ok:
        raise Exception("Call to " + function_name + " failed.")
    return r.content


def temperatures():
    sleep(0.5)
    return get("temperatures")


def subscriptions():
    return get("subscriptions")


def sensor_names():
    return get("sensor_names")


def create_child(name="test"):
    url = picos.event_url(manager_eci, "new_sensor", "sensor", "new_sensor")
    return picos.post(url, data={"name": name})


def add_temp_reading(eci, temp=float(format(random.uniform(10.0, 18.0), '.2f'))):
    heartbeat_url = picos.event_url(
        eci, "temp-reading", "wovyn", "new_temperature_reading")
    return picos.post(heartbeat_url, data={
        "temperature": temp, "timestamp": "now/test"})


def setup_function():
    cleanup()


def teardown_module():
    cleanup()


def test_create_child():
    ok, r = create_child()
    event_name = r.content["directives"][0]["name"]
    child_eci = r.content["directives"][0]["options"]["pico"]["eci"]
    assert ok == True
    assert event_name == "Pico_Created"
    assert child_eci is not None


def test_add_temp_reading():
    ok, r = create_child()
    child_eci = r.content["directives"][0]["options"]["pico"]["eci"]
    assert ok == True

    temp = 18.0
    ok, _ = add_temp_reading(child_eci, temp=temp)
    assert ok == True

    sleep(5)
    temps = temperatures()
    assert temps[0]["temperature"] == temp


def test_subscribe_with_existing_sensor():
    # create an unrelated sensor pico
    child_name = "test-existing"
    root_eci = "XQZfq3v86HdaNE3PXHxeow"
    url = picos.event_url(root_eci, "existing_sensor",
                          "wrangler", "child_creation")
    ok, r = picos.post(url, data={
        "name": child_name,
        "rids": [
            "xandroxygen.temperature_store",
            "xandroxygen.wovyn_base",
            "xandroxygen.sensor_profile",
            "io.picolabs.subscription"
        ]
    })
    assert ok == True

    # get the eci and name of the newly created sensor
    pico_details = r.content["directives"][0]["options"]["pico"]
    child_eci = pico_details["eci"]
    assert child_name == pico_details["name"]

    # wait for everything to finish
    sleep(2)
    url = picos.event_url(manager_eci, "existing_sensor",
                          "sensor", "existing_sensor")
    ok, r = picos.post(url, data={
        "name": child_name,
        "eci": child_eci
    })
    assert ok == True

    # check that the subscription was created
    sleep(2)
    assert len(subscriptions()) > 0

    # delete subscription
    url = picos.event_url(child_eci, "delete", "wrangler",
                          "subscription_cancelled")
    ok, r = picos.post(url)

    # delete extra sensor pico
    url = picos.event_url(root_eci, "delete", "wrangler", "child_deletion")
    ok, r = picos.post(url, data={"name": child_name})
    assert ok == True


def test_multiple_sensors():
    N = 5
    for i in range(N):
        ok, r = create_child(name="test-" + str(i))
        assert ok == True
        child_eci = r.content["directives"][0]["options"]["pico"]["eci"]
        ok, r = add_temp_reading(child_eci)
        assert ok == True

    sleep(2)
    assert len(temperatures()) == N


def test_threshold_violation():
    ok, r = create_child()
    assert ok == True
    child_eci = r.content["directives"][0]["options"]["pico"]["eci"]

    sleep(2)
    temp = 22.0
    ok, r = add_temp_reading(child_eci, temp=temp)
    print(r.content)
    assert ok == True
