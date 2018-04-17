ruleset final.store {
  meta {
    shares __testing, driver_names, orders, bids
    use module io.picolabs.subscription alias Subscriptions
  }
  global {
    __testing = { 
      "queries": [ 
        { "name": "__testing" },
        { "name": "driver_names" },
        { "name": "orders" },
        { "name": "bids" }
      ],
      "events": [ 
        {
          "domain": "store",
          "type": "update",
          "attrs": [ "preferred_ranking", "search_radius"]
        }
      ]
    }
                  
    driver_names = function() {
      engine:listChannels()
      .filter(function(channel) {
        channel["type"] == "subscription"
      })
      .map(function(channel) {
        channel["name"]
      })
    }
    
    hasDrivers = function() {
      Subscriptions:established("Tx_role", "driver").length() > 0
    }
    
    getRandomEl = function(arr) {
      rand = random:integer(arr.length()-1);
      arr[rand]
    }
    
    getDriver = function() {
      driver_ecis = Subscriptions:established("Tx_role", "driver").map(function(sub) { sub{"Tx"} });
      getRandomEl(driver_ecis)
    }
    
    chooseBid = function() {
      getRandomEl(ent:bids)
    }
    
    getOrderId = function() {
      meta:picoId + ":" + ent:n_orders.as("String")
    }
    
    updateObject = function(obj, iKey, iVal, cKey, cVal) {
      obj.map(function(o) {
        o{iKey} == iVal => o.put(cKey, cVal) | o
      })
    }
    
    orders = function() {
      ent:orders
    }
    
    bids = function() {
      ent:bids
    }
  }
  
  rule intialization {
    select when wrangler ruleset_added where rids >< meta:rid
    always {
     ent:orders := [];
     ent:bids := [];
     ent:n_orders := 0;
    }
  }
  
  rule update_profile {
    select when store update
    always {
      ent:ranking := event:attr("preferred_ranking");
      ent:radius := event:attr("search_radius");
    }
  }
  
  rule add_driver {
    select when store driver_added
    pre {
      name = event:attr("name")
      eci = event:attr("eci")
      exists = driver_names >< name
    }
    if not exists then
      noop()
    fired {
      raise wrangler event "subscription" 
        attributes {
          "name": name,
          "Rx_role": "store",
          "Tx_role": "driver",
          "channel_type": "subscription",
          "wellKnown_Tx": eci
        };
    }
  }
  
  rule queue_order {
    select when order placed
    pre {
      order = {
        "order": {
          "id": getOrderId(),
          "location": event:attr("location"),
          "details": event:attr("details"),
          "delivery_time": event:attr("time"),
          "customer_eci": event:attr("eci")
        },
        "preferences": {
          "search_radius": ent:radius,
          "ranking": ent:ranking
        },
        "eci": meta:eci,
        "sent": false,
        "delivered": false
      }
      
    }
    always {
      ent:orders := ent:orders.append(order);
      ent:n_orders := ent:n_orders + 1;
      raise order event "queued" attributes {}
    }
  }
  
  rule send_order {
    select when order queued where hasDrivers()
    foreach ent:orders setting (order)
      pre {
        driver = getDriver()
      }
      if not order{"sent"} then
        event:send({
          "eci": driver,
          "eid": "place_order",
          "domain": "driver",
          "type": "delivery_requested",
          "attrs": order.delete("sent").delete("delivered")
        })
      fired {
        ent:orders := updateObject(ent:orders, "id", order{"id"}, "sent", true)
      }
  }
  
  rule no_drivers {
    select when order queued where not hasDrivers()
    send_directive("no_drivers")
    always {
      schedule order event "queued" at time:add(time:now(), {"seconds": 10})
    }
  }
  
  rule receive_bid {
    select when order bidOnOrder
    always{
      ent:bids := ent:bids.append(event:attr("bid"));
    }
  }
  
  rule start_bids {
    select when order bidOnOrder where ent:bids.length() == 0
    always {
      schedule bid event "finished" at time:add(time:now(), {"seconds": 60})
    }
  }
  
  rule choose_bid {
    select when bid finished
    pre {
      bid = chooseBid()
      b = ent:bids.length().klog("Bid length: ")
    }
    event:send({
      "eci": bid{"driverECI"},
      "eid": "bid",
      "domain": "driver",
      "type": "selected",
      "attrs": bid{"order"}
    })
    always {
      ent:bids := ent:bids.filter(function(b) { b{"driverECI"} != bid{"driverECI"}});
      ent:orders := updateObject(ent:orders, "id", bid{"id"}, "driver_eci", bid{"driverECI"});
      raise bid event "chosen"
    }
  }
  
  rule reject_bids {
    select when bid chosen
    foreach ent:bids setting (bid)
      event:send({
        "eci": bid{"driverECI"},
        "eid": "bid",
        "domain": "bid",
        "type": "rejected"
      })
      always {
        ent:bids := [] on final;
      }
  }
  
  rule order_delivered {
    select when order delivered
    pre {
      order = ent:orders.filter(function(o) { o{"id"} == event:attr("order"){"id"}})
    }
    event:send({
      "eci": order{"driver_eci"},
      "eid": "rerank",
      "domain": "driver",
      "type": "updateRating",
      "attrs": { 
        "rating": event:attr("rating")
      }
    })
    always {
      ent:orders := updateObject(ent:orders, "id", order{"id"}, "delivered", true);
      
    }
  }
}
