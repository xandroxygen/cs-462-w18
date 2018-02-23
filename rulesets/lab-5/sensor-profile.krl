ruleset xandroxygen.sensor_profile {
  meta {
    shares __testing, location, name, threshold, number
    provides location, name, threshold, number
  }
  global {
    __testing = { "queries": [ 
                    { "name": "__testing" },
                    { "name": "location" },
                    { "name": "name" },
                    { "name": "threshold" },
                    { "name": "number" }
                  ],
                  "events": [ ] }
                  
    location = function() {
      ent:location.defaultsTo("The Universe")
    }
    
    name = function() {
      ent:name.defaultsTo("Wovyn One")
    }
    
    threshold = function() {
      ent:threshold.defaultsTo("19.0")
    }
    
    number = function() {
      ent:number.defaultsTo("+13852907346")
    }
  }
  
  rule update_profile {
    select when sensor profile_updated
    always {
      ent:location := event:attr("location").defaultsTo(ent:location);
      ent:name := event:attr("name").defaultsTo(ent:name);
      ent:threshold := event:attr("threshold").defaultsTo(ent:threshold);
      ent:number := event:attr("number").defaultsTo(ent:number);
    }
  }
}
