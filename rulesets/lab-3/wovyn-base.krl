ruleset xandroxygen.wovyn_base {
  meta {
    shares __testing
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
    temperature_threshold = 20.0
    notification_number = "+13852907346"
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
        "threshold": temperature_threshold,
        "timestamp": event:attr("timestamp")
      }
    }
    if temp > temperature_threshold then
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
        "to": notification_number,
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
