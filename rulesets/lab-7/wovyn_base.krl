ruleset xandroxygen.wovyn_base {
  meta {
    shares __testing
    use module xandroxygen.sensor_profile alias profile
     use module io.picolabs.subscription alias Subscriptions
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
                  
    manager_subscription = function() {
      Subscriptions:established("Rx_role","sensor").head()
    }
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
      manager_sub = manager_subscription().klog()
    }
    if temp > profile:threshold().as("Number") then
      event:send({ "eci": manager_sub{"Tx"}, "eid": "violation",
        "domain": "sensor", "type": "threshold_violation", "attrs": attrs
      })
    notfired {
      raise wovyn event "no_violation"
    }
  }
  
  rule no_violation {
    select when wovyn no_violation
    send_directive("no_threshold_violation")
  }
  
  rule auto_accept_subscription {
    select when wrangler inbound_pending_subscription_added
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }
  
  rule delete_subscription {
    select when wovyn delete_subscription
    pre {
      sub_to_delete = manager_subscription()
    }
    if sub_to_delete then noop();
    fired {
      raise wrangler event "subscription_cancellation"
        attributes {"Tx":sub_to_delete{"Tx"}}
    }
  }
  
}
