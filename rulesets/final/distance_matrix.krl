ruleset final.distance_matrix {
  meta {
    shares __testing, distance, current_city
    provides distance, current_city
    configure using api_key = ""
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
                  
    prep_address = function(addr) {
      addr.split(" ").append(ent:city).join("+")
    }
    
    distance = function(origin, dest) {
      qs = {
        "key": api_key,
        "origins": prep_address(origin),
        "destinations": prep_address(dest)
      };
      response = http:get("https://maps.googleapis.com/maps/api/distancematrix/json", qs=qs, parseJSON=true);
      response{"content"}{"status"} == "OK" =>
        response{"content"}{"rows"}[0]{"elements"}[0]{"distance"}{"value"}.as("Number")
        | 999999
    }
    
    current_city = function() {
      ent:city
    }
  }
  
  rule intialization {
    select when wrangler ruleset_added where rids >< meta:rid
    always {
      raise distance event "city" attributes { "city": "Provo" }
    }
  }
  
  rule set_city {
    select when distance city
    always {
      ent:city := event:attr("city").defaultsTo("Provo")
    }
  }
}
