ruleset xandroxygen.notify_sms {
  meta {
    shares __testing
  }
  global {
    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
                  
    number = function() {
      ent:number.defaultsTo("+13852907346")
    }
  }
  
  rule update_number {
    select when notify update_number
    always {
      ent:number := event:attr("number").defaultsTo(ent:number);
    }
  }
  
  rule send_sms {
    select when notify send
    pre {
      from = "+13852557485"
      message = event:attr("message")
      attrs = {
        "to": number(),
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
