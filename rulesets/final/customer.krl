ruleset final.customer {
  meta {
    shares __testing
  }
  global {
    __testing = { 
      "queries": [ 
        { "name": "__testing" } 
      ],
      "events": [ 
        {
          "domain": "customer",
          "type": "update_store",
          "attrs": [ "eci" ]
        },
        {
          "domain": "customer",
          "type": "update_location",
          "attrs": [ "location" ]
        },
        {
          "domain": "customer",
          "type": "order",
          "attrs": [ "details" ]
        }
      ] }
  }
  
  rule update_store {
    select when customer update_store
    always {
      ent:store := event:attr("eci")
    }
  }
  
  
  rule update_location {
    select when customer update_location
    always {
      ent:location := event:attr("location")
    }
  }
  
  rule place_order {
    select when customer order
    event:send({
      "eci": ent:store,
      "eid": "order",
      "domain": "order",
      "type": "placed",
      "attrs": {
        "location": ent:location,
        "delivery_time": time:now(),
        "details": event:attr("details"),
        "eci": meta:eci
      }
    })
  }
  
  rule order_delivered {
    select when order delivered
    event:send({
      "eci": ent:store,
      "eid": "ranking",
      "domain": "order",
      "type": "delivered",
      "attrs": {
        "order": event:attrs,
        "rating": random:number(5)
      }
    })
    always {
      raise notify event "send" 
        attributes { "message": <<Your order '#{event:attr("details")}' has been delivered>> }
    }
  }
}
