ruleset xandroxygen.manage_sensors {
  meta {
    shares __testing, sensors, temperatures
    provides sensors, temperatures
  }
  global {
    __testing = { "queries": [ { "name": "__testing" },
                                { "name": "sensors" } ],
                  "events": [ ] }
                  
    sensors = function() {
      ent:sensors
    }
    
    notification_number = "+13852907346"
    default_threshold = "20.0"
    
    // Calling cloud function via API with ECI
    // Borrowed and adapted with love from Dr Windley at
    // https://picolabs.atlassian.net/wiki/spaces/docs/pages/1184812/Calling+a+Module+Function+in+Another+Pico
    cloud = function(eci, mod, func, params) {
        url = meta:host + "/sky/cloud/" + eci + "/" + mod + "/" + func;
        response = http:get(url, (params || {}));
        response{"content"}.decode();
    };
    
    temperatures = function() {
      sensor_temps = ent:sensors.map(function(eci,name) {
        cloud(eci, "xandroxygen.temperature_store", "temperatures")
      });
      sensor_temps.values().reduce(function(acc, val) {
        acc.append(val)
      }, [])
    }
  }
  
  rule intialization {
    select when wrangler ruleset_added where rids >< meta:rid
    fired {
      ent:id := 0;
      ent:sensors := {};
    }
  }
  
  rule sensor_already_exists {
    select when sensor new_sensor
    pre {
      name = event:attr("name").defaultsTo("Sensor #" + ent:id)
      exists = ent:sensors >< name
    }
    if exists then
      send_directive("duplicate_sensor", { "name": name })
  }
  
  rule create_sensor {
    select when sensor new_sensor
    pre {
      name = event:attr("name").defaultsTo("Sensor #" + ent:id)
      exists = ent:sensors >< name
    }
    if not exists then
      noop()
    fired {
      ent:id := ent:id + 1;
      raise wrangler event "child_creation"
        attributes {  
          "name": name,
          "color": "#7fffd4",
          "rids": [
            "xandroxygen.temperature_store",
            "xandroxygen.wovyn_base",
            "xandroxygen.sensor_profile"
          ]
        }
    }
  }
  
  rule store_sensor {
    select when wrangler child_initialized
    pre {
      name = event:attr("name")
      eci = event:attr("eci")
    }
    fired {
      ent:sensors := ent:sensors.put([name], eci);
      raise sensor event "sensor_updated"
        attributes {
          "name": name,
          "threshold": default_threshold,
          "number": notification_number
        }
    }
  }
  
  rule delete_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attr("name")
    }
    fired {
      ent:sensors := ent:sensors.delete([name]);
      raise wrangler event "child_deletion"
        attributes {
          "name": name
        }
    }
  }
  
  rule reset_variables {
    select when sensor reset_variables
    fired {
      ent:id := 0;
      ent:sensors := {};
    }
  }
}
