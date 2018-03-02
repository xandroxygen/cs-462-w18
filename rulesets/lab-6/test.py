from urllib.request import urlopen
from urllib.parse import urlencode
from urllib.error import HTTPError
from time import sleep
import json

# -----------------
# Define Base Stuff
# -----------------

base_url = "http://localhost:8080"
eci = "4Ckeye7ss23fVvkyN97bYN"
eid = "test"


def build_cloud_url(eci):
    return base_url + "/sky/cloud/" + eci


def build_event_url(eci):
    return base_url + "/sky/event/" + eci + "/" + eid


event_url = build_event_url(eci)
cloud_url = build_cloud_url(eci)
sensors_url = cloud_url + "/xandroxygen.manage_sensors/sensors"

# ----------------
# Helper Functions
# ----------------


def get(url):
    return urlopen(url).read().decode()


def fire_rule(domain, _type, params=""):
    url = event_url + "/" + domain + "/" + _type
    if params:
        url += "?" + params
    return get(url)


def get_sensors():
    return get(sensors_url)


def remove_all_sensors():
    sensors = json.loads(get_sensors())
    for name in sensors:
        fire_rule("sensor", "unneeded_sensor", urlencode({"name": name}))
        sleep(0.5)
    fire_rule("sensor", "reset_variables")


def test(name, content, condition):
    remove_all_sensors()
    print("Test: " + name)
    content()
    sleep(0.5)
    try:
        assert condition()
        print("Passed")
    except AssertionError:
        print("Failed")
    except HTTPError as e:
        print(e.reason)


# -----
# Tests
# -----


# 1
test(
    "Create child",
    lambda: fire_rule("sensor", "new_sensor"),
    lambda: "Sensor #0" in get_sensors()
)

# 2
test(
    "Create child with name",
    lambda: fire_rule("sensor", "new_sensor", "name=test"),
    lambda: "test" in get_sensors()
)

# 3


def check_profile():
    new_eci = json.loads(get_sensors())["test"]
    new_url = build_cloud_url(new_eci) + "/xandroxygen.sensor_profile"
    threshold = get(new_url + "/threshold")
    number = get(new_url + "/number")
    return "19.0" in threshold and "3852907346" in number


test(
    "Check that profile info is set on child",
    lambda: fire_rule("sensor", "new_sensor", "name=test"),
    check_profile
)

# 4


def check_dupes():
    response = fire_rule("sensor", "new_sensor", "name=test")
    return "duplicate_sensor" in response


test(
    "Adding sensors with duplicate names should fail",
    lambda: fire_rule("sensor", "new_sensor", "name=test"),
    check_dupes
)

# 5


def check_deleted():
    fire_rule("sensor", "unneeded_sensor", "name=test")
    sleep(0.5)
    return "test" not in get_sensors()


test(
    "Delete sensor pico",
    lambda: fire_rule("sensor", "new_sensor", "name=test"),
    check_deleted
)

# 6


def check_temperature_events():
    new_eci = json.loads(get_sensors())["test"]
    data = urlencode({"temperature": 18.0, "timestamp": "now/test"})
    new_url = build_event_url(
        new_eci) + "/wovyn/new_temperature_reading?" + data
    get(new_url)
    sleep(0.5)
    query_url = build_cloud_url(
        new_eci) + "/xandroxygen.temperature_store/temperatures"
    temperatures = get(query_url)
    return "18.0" in temperatures


test(
    "Created sensors receive heartbeat readings properly",
    lambda: fire_rule("sensor", "new_sensor", "name=test"),
    check_temperature_events
)

# 7


def create_sensors():
    fire_rule("sensor", "new_sensor")
    fire_rule("sensor", "new_sensor")
    fire_rule("sensor", "new_sensor")


def fire_temp_readings(sensors):
    temp = 15.0
    for _, eci in sensors.items():
        data = urlencode({"temperature": temp, "timestamp": "now/test"})
        get(build_event_url(eci) + "/wovyn/new_temperature_reading?" + data)
        temp += 1.0


def check_aggregate_temps():
    fire_temp_readings(json.loads(get_sensors()))
    sleep(0.5)
    temperatures = get(cloud_url + "/xandroxygen.manage_sensors/temperatures")
    print(temperatures)
    return "15.0" in temperatures and "16.0" in temperatures and "17.0" in temperatures


test(
    "Check that aggregate temps include all sensors",
    create_sensors,
    check_aggregate_temps
)

# Cleanup
remove_all_sensors()
