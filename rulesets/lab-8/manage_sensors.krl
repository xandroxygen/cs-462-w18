ruleset xandroxygen.manage_sensors {
  meta {
    shares __testing, temperatures, subscriptions, sensor_names, all_temp_reports, recent_reports
    provides temperatures, subscriptions, sensor_names, all_temp_reports, recent_reports
    use module io.picolabs.subscription alias Subscriptions
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
    
    notification_number = "+13852907346"
    default_threshold = "20.0"

    cloud = function(eci, mod, func, params) {
        url = meta:host + "/sky/cloud/" + eci + "/" + mod + "/" + func;
        response = http:get(url, (params || {}));
        response{"content"}.decode();
    };
    
    temperatures = function() {
      sensor_temps = Subscriptions:established("Tx_role", "sensor").map(function(subscription) {
        eci = subscription{"Tx"};
        cloud(eci, "xandroxygen.temperature_store", "temperatures")
      });
      
      sensor_temps.values().reduce(function(acc, val) {
        acc.append(val)
      }, [])
    }
    
    subscriptions = function() {
      Subscriptions:established()
    }
    
    all_temp_reports = function() {
      ent:reports
    }
    
    recent_reports = function() {
      ent:reports
        .values()
        .sort(function(a,b) {
          // get number from correlation_ids
          a_id = a{"correlation_id"}.split(":").reverse().head().as("Number");
          b_id = b{"correlation_id"}.split(":").reverse().head().as("Number");
          a_id <=> b_id
        })
        .reverse()
        .slice(4)
    }
    
    sensor_names = function() {
      engine:listChannels()
      .filter(function(channel) {
        channel["type"] == "subscription"
      })
      .map(function(channel) {
        channel["name"]
      })
    }
  }
  
  rule intialization {
    select when wrangler ruleset_added where rids >< meta:rid
    fired {
      ent:corr := random:word();
      ent:report_num := 0;
      ent:reports := {};
      raise notify event "update_number"
        attributes {
          "number": notification_number
        }
    }
  }
  
  rule request_temp_report {
    select when sensor temperature_report
    foreach Subscriptions:established("Tx_role", "sensor") setting (subscription)
      pre {
        cid = ent:corr + ":" + ent:report_num
      }
      event:send({ 
        "eci": subscription{"Tx"}, 
        "eid": "reports", 
        "domain": "wovyn", 
        "type": "collect_temp_report", 
        "attrs": { 
          "correlation_id": cid
        } 
      })
  }
  
  rule begin_temp_report_request {
    select when sensor temperature_report
    pre {
      cid = ent:corr + ":" + ent:report_num
      num = Subscriptions:established("Tx_role", "sensor").length()
      report = {
        "correlation_id": cid,
        "sensors": num,
        "responding": 0,
        "temperatures": []
      }
    }
    send_directive("temp_report_requested", { "correlation_id": cid })
    fired {
      ent:reports := ent:reports.put(cid, report);
      ent:report_num := ent:report_num + 1;
    }
  }
  
  rule respond_to_report {
    select when sensor report_response
    pre {
      cid = event:attr("correlation_id").klog()
      temps = event:attr("temperatures")
      report = ent:reports{cid}
    }
    always {
      ent:reports.klog();
      report{"responding"} = report{"responding"} + 1;
      report{"temperatures"} = report{"temperatures"}.append(temps);
      ent:reports := ent:reports.put(cid, report);
    }
  }
  
  rule sensor_already_exists {
    select when sensor new_sensor
    pre { 
      name = event:attr("name").defaultsTo("sensor-" + random:word())
      exists = sensor_names >< name
    }
    if exists then
      send_directive("duplicate_sensor", { "name": name })
  }
  
  rule create_sensor {
    select when sensor new_sensor
    pre {
      name = event:attr("name").defaultsTo("sensor-" + random:word())
      exists = sensor_names >< name
    }
    if not exists then
      noop()
    fired {
      raise wrangler event "child_creation"
        attributes {  
          "name": name,
          "color": "#7fffd4",
          "rids": [
            "xandroxygen.temperature_store",
            "xandroxygen.wovyn_base",
            "xandroxygen.sensor_profile",
            "io.picolabs.subscription"
          ]
        }
    }
  }
  
  rule duplicate_existing_sensor {
    select when sensor existing_sensor
    pre {
      name = event:attr("name").defaultsTo("Sensor #" + random:word())
      exists = sensor_names >< name
    }
    if exists then
      send_directive("duplicate_sensor", { "name": name })
  }
  
  rule add_existing_sensor {
    select when sensor existing_sensor
    pre {
      name = event:attr("name")
      eci = event:attr("eci")
      exists = sensor_names >< name
    }
    if not exists then
      noop()
    fired {
      raise sensor event "sensor_updated"
        attributes {
          "name": name,
          "threshold": default_threshold,
          "number": notification_number
        };
      raise wrangler event "subscription" 
        attributes {
          "name": name,
          "Rx_role": "controller",
          "Tx_role": "sensor",
          "channel_type": "subscription",
          "wellKnown_Tx": eci
        };
    }
  }
  
  rule store_sensor {
    select when wrangler child_initialized
    pre {
      name = event:attr("name")
      eci = event:attr("eci")
    }
    fired {
      raise sensor event "sensor_updated"
        attributes {
          "name": name,
          "threshold": default_threshold,
          "number": notification_number
        };
      raise wrangler event "subscription" 
        attributes {
          "name": name,
          "Rx_role": "controller",
          "Tx_role": "sensor",
          "channel_type": "subscription",
          "wellKnown_Tx": eci
        };
    }
  }
  
  rule threshold_violation {
    select when sensor threshold_violation
    pre {
      temp = event:attr("temperature")
      threshold = event:attr("threshold")
      message = <<
      Warning: Wovyn Temperature Violation. Temp: #{temp}, Threshold: #{threshold}
      >>
    }
    fired {
      raise notify event "send"
        attributes {
          "message": message
        }
    }
  }
  
  rule delete_sensor {
    select when sensor unneeded_sensor
    pre {
      name = event:attr("name")
    }
    fired {
      raise wrangler event "child_deletion"
        attributes {
          "name": name
        }
    }
  }
  
  rule delete_subscriptions {
    select when sensor delete_subscriptions
    foreach Subscriptions:established("Tx_role", "sensor") setting (subscription)
        event:send({ "eci": subscription{"Tx"}, "eid": "delete",
        "domain": "wrangler", "type": "subscription_cancellation" })
  }
  
  rule reset_reports {
    select when sensor reset_reports
    fired {
      ent:corr := random:word();
      ent:report_num := 0;
      ent:reports := {};
    }
  }
}
