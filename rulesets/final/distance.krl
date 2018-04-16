ruleset final.distance {
  meta {
    shares __testing
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
  }
  
  rule get_distance {
    select when distance get
    pre {
      dist = distance:distance(event:attr("origin"), event:attr("dest"))
    }
    send_directive("distance", {"distance":dist})
    always {
      raise distance event "got"
        attributes { "distance": dist }
    }
  }
}
