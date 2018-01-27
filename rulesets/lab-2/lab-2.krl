ruleset xandroxygen.lab_2 {
  meta {
    use module xandroxygen.twilio_keys
    use module xandroxygen.twilio alias twilio 
      with account_sid = keys:twilio{"account_sid"}
           auth_token = keys:twilio{"auth_token"}  
  } 

  rule test_send_sms {
    select when test new_message
    twilio:send_sms(event:attr("to"),
                    event:attr("from"),
                    event:attr("message")
                   )
  }

  rule test_get_messages {
    select when test get_messages
    pre {
      messages = twilio:messages(event:attr("page_size"), event:attr("filter_to"), event:attr("filter_from"))
    }
    send_directive("say", messages)
  }
}