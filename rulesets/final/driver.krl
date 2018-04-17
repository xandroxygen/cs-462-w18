ruleset final.driver {
  meta {
    shares __testing, rumors, seen, seenByPeers, peers, getBids, getWaitingBid, getRating, getLocation
    use module io.picolabs.subscription alias Subscriptions
    use module final.dm_keys
    use module final.distance alias distance
  }
  
  global {
    __testing = { 
      "queries": [ 
        { "name": "__testing" }, 
        { "name": "rumors" },
        { "name": "seen" },
        { "name": "seenByPeers" },
        { "name": "peers" },
        {"name": "getBids"},
        {"name": "getWaitingBid"},
        {"name": "getRating"},
        {"name": "getLocation"}
      ],
      "events": [ 
        {
          "domain": "driver",
          "type": "reset"
        },
        {
          "domain": "gossip",
          "type": "init"
        },
        {
          "domain": "gossip",
          "type": "stop"
        },
        {
          "domain": "gossip",
          "type": "process",
          "attrs": [
            "status"
          ]
        },
        {
          "domain": "gossip",
          "type": "update_n",
          "attrs": [
            "n"
          ]
        },
        {
          "domain": "driver",
          "type": "updateRating",
          "attrs": ["rating"]
          
        },
        {
          "domain": "driver",
          "type": "setLocation",
          "attrs": ["location"]}
      ] 
    }
                  
    rumors = function() { ent:rumors }
    seen = function() { ent:seen }
    seenByPeers = function() { ent:seenByPeers }
    peers = function() { ent:peers }
          
    // for all peers, find how many rumors they don't know about
    // return the peer with the most rumors, or a random peer
    // if everyone is caught up
    getPeer = function() {
      sensorIds = ent:peers.keys();
      peerLength = sensorIds.length();
      randomSensorId = sensorIds[random:integer(peerLength-1)];
      randomInt = random:integer(2);
      
      randomInt == 0 => getPeerByRumor(sensorIds).defaultsTo(randomSensorId) |
      randomInt == 1 => getPeerBySeen(sensorIds).defaultsTo(randomSensorId) |
      randomSensorId
    }
    
    getPeerByRumor = function(sensorIds) {
      sensorIds
        .map(function(sensorId) {
          {
            "numNeededRumors": getUnknownRumors(ent:seenByPeers{sensorId}).length(),
            "sensorId": sensorId
          }
        })
        .filter(function(a) { a{"numNeededRumors"} > 0})
        .sort(function(a, b) { a{"numNeededRumors"} <=> b{"numNeededRumors"} })
        .head(){"sensorId"}
    }
    
    getPeerBySeen = function(sensorIds) {
       sensorIds
        .map(function(sensorId) {
          {
            "differenceSeen": ent:seen.keys().length() - ent:seenByPeers{sensorId}.keys().length(),
            "sensorId": sensorId
          }
        })
        .filter(function(a) { a{"differenceSeen"} > 0})
        .sort(function(a, b) { a{"differenceSeen"} <=> b{"differenceSeen"} })
        .head(){"sensorId"}
    }
    
    updatePeers = function() {
      Subscriptions:established("Tx_role", "driver").reduce(function(peers, sub) {
        sensorId = engine:getPicoIDByECI(sub{"Tx"});
        peers.put(sensorId, sub{"Tx"})
      }, {})
    }
    
    prepareMessage = function(sensorId) {
      (random:integer(1) == 0) => 
      {
        "message": getNeededRumor(sensorId),
        "type": "rumor" 
      } | {
        "message": {
          "Seen": ent:seen,
          "SensorID": meta:picoId
        },
        "type": "seen"
      }
    }
    
    getNeededRumor = function(sensorId) {
      seenBySensorID = ent:seenByPeers{sensorId};
      neededRumors = getUnknownRumors(seenBySensorID);
      neededRumors.head().defaultsTo(ent:rumors[random:integer(ent:rumors.length()-1)])
    }
    
    createSelfRumor = function(order) {
      {
        "MessageID": meta:picoId + ":" + ent:sqn.as("String"),
        "SensorID": meta:picoId,
        "order": order,
        "Timestamp": time:now()
      };
    }
    
    createRumor = function(mid, sid, order, time) {
      { 
        "MessageID": mid,
        "SensorID": sid,
        "order": order,
        "Timestamp": time
      }
    }
    
    getSequenceNumber = function(messageId) {
      parts = messageId.split(":");
      parts[1];
    }
    
    getHighestCompleteSequenceNumber = function(messageId) {
      parts = messageId.split(":");
      originId = parts[0];
      sqn = parts[1].as("Number").klog("sqn: ");
      hcsqn = ent:seen{originId}.defaultsTo(0).klog("hcsqn: ");
      (sqn == hcsqn + 1) => sqn | hcsqn
    }
    
    getUnknownRumors = function (seenByPeer) {
      toSend = [];
      
      // check for difference between origins, or any new sensors
        // send all rumors from new sensors
      newSensorIds = ent:seen.keys().difference(seenByPeer.keys());
      newSensorRumors = newSensorIds.reduce(function(rumors, id) {
        idRumors = ent:rumors.filter(function(r) { r{"SensorID"} == id});
        rumors.append(idRumors)
      }, []);
      toSend = toSend.append(newSensorRumors);
      
      // check each origin for difference in hcsqn
        // send rumors to make up difference
      existingSensorRumors = seenByPeer.keys().reduce(function(rumors, id) {
        peerSqn = seenByPeer{id};
        selfSqn = ent:seen{id};
        
        // find rumors with that id that has sqn between self and peer
        idRumors = ent:rumors.filter(function(r) {
          rSqn = getSequenceNumber(r{"MessageID"});
          r{"SensorID"} == id && rSqn > selfSqn && rSqn <= peerSqn;
        });
        rumors.append(idRumors);
      }, []);
      toSend = toSend.append(existingSensorRumors);
      
      toSend
    }
    
    ////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////
    
    getBids = function() {
      ent:queueOfBids
    }
  
    
    getLocation = function() {
      ent:location
    }

    
    getDistance = function(driverLocation, customerLocation) {
      distance:get_distance(driverLocation, customerLocation)
    }
    
    canBid = function(order)
    {
      //check this 
      //distance:is_dest_in_radius(customerLocation, driverLocation, ent:prefDistance);
      true
    }
    
    getRating = function() {
      ent:rating
    }
    
    getWaitingBid = function() {
      ent:waitingBid
    }

  }
  
  rule ruleset_added {
    select when wrangler ruleset_added where rids >< meta:rid
    always {
      ent:rating := random:integer(10);
      ent:location := "1209 North 900 East";
      ent:prefDistance := 20000;
      ent:gossippedIDs := [];
      ent:waitingBid := null;
      ent:queueOfBids := [];

    }
  }
  
  rule reset {
    select when driver reset
    always {
      ent:waitingBid := null;
      ent:queueOfBids := [];
      ent:gossippedIDs := [];
    }
  }
  
  rule set_location {
    select when driver setLocation
    pre {
      location = event:attr("location").defaultsTo("1209 North 900 East")
    }
    always {
      ent:location := location; 
    }
  }
  
  rule update_rating {
    select when driver updateRating
    pre {
      updatedRating = event:attr("rating").as("Number").defaultsTo(ent:rating)
    }
    always {
      ent:rating := updatedRating
    }
  }
  
  rule bid_selected {
    select when driver selected
    always {
      schedule order event "delivered" at time:add(time:now(),
      {"seconds": random:integer(upper = 20, lower = 10)}) attributes event:attrs;
      ent:waitingBid := null;
    }
  }
  
  rule bid_rejected {
    select when bid rejected
    always {
      "one".klog("REJECTED");
      ent:waitingBid := null;
      ent:queueOfBids := [];
    }
  }
  
  rule try_next_bid {
    select when driver tryNextBid
    pre {
      nextBid = ent:queueOfBids.head().klog("nextBid: ")
      bidSafe = not nextBid.isnull()
    }
    if bidSafe && canBid(nextBid) then
    //CHECK THIS 
      event:send( {"eci": nextBid{"storeECI"},
        "eid": "offer_bid",
        "domain": "order", "type": "bidOnOrder",
        "attrs": {"bid": nextBid}} )
    
    fired {
      ent:queueOfBids := ent:queueOfBids.tail();
      ent:waitingBid := nextBid if bidSafe && canBid(nextBid);
    }
  }
  
  
  rule driver_requested {
    select when driver delivery_requested where (not (ent:gossippedIDs >< event:attr("order"){"id"})).klog("UnGossipped: ")
    pre {
      storeECI = event:attr("eci")
      order = event:attr("order")
      customerLoc = event:attr("order"){"location"}
      
      bid = {
        "id": order{"id"},
        "customerECI": event:attr("order"){"customer_eci"},
        "order": order,
        "driverLocation": ent:location,
        "rating": ent:rating,
        "driverECI": meta:eci,
        "storeECI": storeECI,
        "customerLocation": customerLoc
      
      }
    }
    always {
        ent:queueOfBids := ent:queueOfBids.append(bid);
        raise driver event "tryNextBid" if ent:waitingBid.isnull();
        
        raise driver event "gossip" attributes event:attrs;
        ent:gossippedIDs := ent:gossippedIDs.append(order{"id"})
        
      }
    }
    
  
  
  rule order_delivered {
    select when order delivered
    event:send({
      "eci": event:attr("customer_eci"),
      "eid": "delivered",
      "domain": "order",
      "type": "delivered",
      "attrs": event:attrs
    })
  }

  
  
  
  //////////////////////////////////////////////
  /////////////////////////////////////////////////
  
  rule init {
    select when gossip init
    always {
      ent:run := true;
      ent:n := 10;
      ent:sqn := 0;
      ent:seen := {};
      ent:rumors := [];
      ent:peers := updatePeers();
      ent:seenByPeers := {};
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:n})
    }
  }
  
  rule stop {
    select when gossip stop
    always {
      ent:run := false;
    }
  }
  
  rule toggle_processing {
    select when gossip process
    always {
      ent:run := event:attr("status") == "on"
    }
  }
  
  rule heartbeat {
    select when gossip heartbeat where ent:run
    pre {
      sensorId = getPeer()
      message = prepareMessage(sensorId)
      eci = ent:peers{sensorId}
    }
    if not message{"message"}.isnull() then
      event:send({ 
        "eci": eci, 
        "eid": "heartbeat",
        "domain": "gossip", 
        "type": message{"type"}, 
        "attrs": message{"message"} 
      })
    always {
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": ent:n})
    }
  }
  
  rule update_n {
    select when gossip update_n
    always {
      ent:n := event:attr("n").as("Number")
    }
  }
  
  rule update_peers {
    select when gossip update_peers
    always {
      ent:peers := updatePeers()
    }
  }
  
  rule store_rumor {
    select when gossip rumor where ent:run
    pre {
      rumor = createRumor(
        event:attr("MessageID"),
        event:attr("SensorID"),
        event:attr("order"),
        event:attr("Timestamp")
        )
      hcsqn = getHighestCompleteSequenceNumber(event:attr("MessageID"))
    }
    if not ent:rumors.any(function(r) { r{"MessageID"} == rumor{"MessageID"}}) then
      noop()
    fired {
      ent:rumors := ent:rumors.append(rumor);
      raise driver event "delivery_requested" attributes event:attr("order");
    }
    finally {
      ent:seen := ent:seen.put(event:attr("SensorID"), hcsqn);
    }
  }
  
  rule log_seen {
    select when gossip seen where ent:run
    always {
      ent:seenByPeers := ent:seenByPeers.put(event:attr("SensorID"), event:attr("Seen"))
        .klog("seenByPeers for sensor " + meta:picoId + " and sensor " + event:attr("SensorID") + ": ")
    }
  }
  
  rule share_seen {
    select when gossip seen where ent:run
    foreach getUnknownRumors(event:attr("Seen")) setting (rumor)
      pre {
        eci = ent:peers{event:attr("SensorID")}
      }
      event:send({ 
        "eci": eci, 
        "eid": "heartbeat",
        "domain": "gossip", 
        "type": "rumor", 
        "attrs": rumor
      });
  }
  
  rule create_rumor {
    select when driver gossip where ent:run
    pre {
      order = event:attrs
      rumor = createSelfRumor(order)
    }
    always {
      ent:rumors := ent:rumors.append(rumor)
        if not ent:rumors.any(function(r) { r{"MessageID"} == rumor{"MessageID"}}); 
      ent:seen := ent:seen.put(meta:picoId, ent:sqn);
      ent:sqn := ent:sqn + 1
    }
  }
}