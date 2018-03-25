import picosapi as picos
import pytest
from time import sleep
import random
from pprint import pprint

# -----------------
# Define Base Stuff
# -----------------

base_url = "http://localhost:8080"
manager_eci = "7ZqrGLcDFWFvB1tKfXuRHV"
manager_pico_id = "xandroxygen.manage_sensors"
picos.set_config("Host", "localhost")
picos.set_config("Port", "8080")

# -----
# Helpers
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

    # reset reports variables
    url = picos.event_url(manager_eci, "reset", "sensor", "reset_reports")
    picos.post(url)


def delete_subscriptions():
    url = picos.event_url(manager_eci, "delete",
                          "sensor", "delete_subscriptions")
    ok, r = picos.post(url)
    if not ok:
        raise Exception("Call to `delete subscriptions` failed.")
    return r.content


def setup_function():
    cleanup()


def teardown_module():
    cleanup()


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


def all_reports():
    return get("all_temp_reports")


def recent_reports():
    return get("recent_reports")


def create_child(name="test"):
    url = picos.event_url(manager_eci, "new_sensor", "sensor", "new_sensor")
    return picos.post(url, data={"name": name})


def add_temp_reading(eci, temp=float(format(random.uniform(10.0, 18.0), '.2f'))):
    heartbeat_url = picos.event_url(
        eci, "temp-reading", "wovyn", "new_temperature_reading")
    return picos.post(heartbeat_url, data={
        "temperature": temp, "timestamp": "now/test"})


def request_temp_report():
    report_url = picos.event_url(
        manager_eci, "report", "sensor", "temperature_report")
    ok, r = picos.post(report_url)
    if not ok:
        raise Exception("Call to `temperature_report` failed.")
    return r.content["directives"][0]["options"]["correlation_id"]


# -----
# Tests
# -----


def test_report_correlation_id_increments():
    ok, _ = create_child()
    assert ok == True

    sleep(0.5)
    cid1 = request_temp_report().split(":").pop()

    sleep(0.5)
    cid2 = request_temp_report().split(":").pop()

    assert int(cid1) + 1 == int(cid2)


def test_report_includes_temps_from_all_sensors():
    # child 1
    ok, r = create_child()
    child_eci = r.content["directives"][0]["options"]["pico"]["eci"]
    assert ok == True

    sleep(0.5)
    temp = 18.0
    ok, _ = add_temp_reading(child_eci, temp=temp)
    assert ok == True

    # child 2
    ok, r = create_child()
    child_eci = r.content["directives"][0]["options"]["pico"]["eci"]
    assert ok == True

    sleep(0.5)
    temp = 17.0
    ok, _ = add_temp_reading(child_eci, temp=temp)
    assert ok == True

    # get temp report
    sleep(0.5)
    cid = request_temp_report()

    sleep(0.5)
    reports = all_reports()
    assert len(reports) == 1

    temps = [reading["temperature"]
             for reading in reports[cid]["temperatures"]]
    assert temps == [18.0, 17.0]


def test_get_5_last_reports():
    ok, r = create_child()
    child_eci = r.content["directives"][0]["options"]["pico"]["eci"]
    assert ok == True

    sleep(0.5)
    temp = 18.0
    ok, _ = add_temp_reading(child_eci, temp=temp)
    assert ok == True

    # create 6 reports()
    cids = []
    for _ in range(6):
        sleep(0.5)
        cids.append(request_temp_report())

    # should return the last 5 reports, 5-1
    reports = recent_reports()
    pprint(reports)

    report_ids = [int(report["correlation_id"].split(":").pop())
                  for report in reports]
    assert sorted(report_ids, reverse=True) == report_ids
    assert min(report_ids) == 1
    assert max(report_ids) == 5
    assert len(reports) == 5
