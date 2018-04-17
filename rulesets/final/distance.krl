ruleset final.distance {
  meta {
    shares __testing, get_distance, is_dest_in_radius
    provides get_distance, is_dest_in_radius
    use module final.dm_keys
    use module final.distance_matrix alias distance
      with api_key = keys:distance_matrix{"api_key"}
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ 
                    {
                      "domain": "distance",
                      "type": "get",
                      "attrs": [ "origin", "dest"]
                    },
                    {
                      "domain": "distance",
                      "type": "city",
                      "attrs": ["city"]
                    }
                  ] }
                  
      get_distance = function(origin, dest) {
        distance:distance(origin, dest)
      }
      
      is_dest_in_radius = function(origin, dest, radius) {
        distance = distance:distance(origin, dest);
        distance.as("Number") < radius.as("Number")
      }
  }
}
