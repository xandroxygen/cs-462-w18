ruleset final.notify_sms {
  meta {
    shares __testing
    use module final.twilio_keys
    use module final.twilio alias twilio 
      with account_sid = keys:twilio{"account_sid"}
           auth_token = keys:twilio{"auth_token"} 
  }
  global {
    __testing = { 
      "queries": [ 
        { "name": "__testing" } 
      ],
      "events": [ 
        {
          "domain": "notify",
          "type": "update_number",
          "attrs": [
            "number"  
          ]
        },
        {
          "domain": "notify",
          "type": "send",
          "attrs": [
            "message"  
          ]
        }
      ] 
    }
                  
    
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
    }
    twilio:send_sms(number(), from, message)
  }
}
