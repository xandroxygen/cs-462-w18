ruleset xandroxygen.wovyn_base {
  meta {
    shares __testing
    use module xandroxygen.sensor_profile alias profile
  }
  global {
    __testing = { "events": [ 
                    {
                      "domain": "wovyn",
                      "type": "heartbeat",
                      "attrs": [
                        "genericThing"  
                      ]
                    },
                    {
                      "domain": "wovyn",
                      "type": "new_temperature_reading",
                      "attrs": [
                        "temperature",
                        "timestamp"
                      ]
                    },
                    {
                      "domain": "wovyn",
                      "type": "threshold_violation",
                      "attrs": [
                        "temperature",
                        "threshold",
                        "timestamp"
                      ]
                    }
                  ] }
  }
  
  rule process_heartbeat {
    select when wovyn heartbeat where
      not event:attr("genericThing").isnull()
    pre {
      attrs = { 
        "temperature": event:attr("genericThing")["data"]["temperature"][0]["temperatureC"], 
        "timestamp": time:now() 
      }
    }
    send_directive("heartbeat")
    fired {
      raise wovyn event "new_temperature_reading"
        attributes attrs
    }
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
      temp = event:attr("temperature")
      attrs = {
        "temperature": temp,
        "threshold": profile:threshold().as("Number"),
        "timestamp": event:attr("timestamp")
      }
    }
    if temp > profile:threshold().as("Number") then
      send_directive("violation", {"temperature": temp })
    fired {
      raise wovyn event "threshold_violation"
        attributes attrs
    } else {
      raise wovyn event "no_violation"
    }
  }
  
  rule no_violation {
    select when wovyn no_violation
    send_directive("no_threshold_violation")
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    pre {
      from = "+13852557485"
      temp = event:attr("temperature")
      threshold = event:attr("threshold")
      message = <<
      Warning: Wovyn Temperature Violation. Temp: #{temp}, Threshold: #{threshold}
      >>
      attrs = {
        "to": profile:number(),
        "from": from,
        "message": message
      }
    }
    fired {
      raise test event "new_message"
        attributes attrs
    }
  }
  
}
