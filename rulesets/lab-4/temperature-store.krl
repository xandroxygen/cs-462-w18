ruleset xandroxygen.temperature_store {
  meta {
    shares __testing, temperatures, threshold_violations, inrange_temperatures
    provides temperatures, threshold_violations, inrange_temperatures
  }
  global {
    __testing = { "queries": [ 
                    { "name": "__testing" },
                    { "name": "temperatures" },
                    { "name": "threshold_violations" },
                    { "name": "inrange_temperatures" }
                  ],
                  "events": [ ] }
                  
    temperatures = function() {
      ent:all_temps
    }
    
    threshold_violations = function() {
      ent:violations
    }
    
    inrange_temperatures = function() {
      ent:all_temps.difference(ent:violations)
    }
    
  }
  
  rule collect_temperatures {
    select when wovyn new_temperature_reading
    always {
      ent:all_temps := ent:all_temps.defaultsTo([]);
      ent:all_temps := ent:all_temps.append({
          "temperature": event:attr("temperature"),
          "timestamp": event:attr("timestamp")
        });
    }
  }
  
  rule collect_threshold_violations {
    select when wovyn threshold_violation
    always {
      ent:violations := ent:violations.defaultsTo([]);
      ent:violations := ent:violations.append({
        "temperature": event:attr("temperature"),
        "timestamp": event:attr("timestamp")
      })
    }
  }
  
  rule clear_temperatures {
    select when sensor reading_reset
    always {
      ent:all_temps := [];
      ent:violations := [];
    }
  }
}
