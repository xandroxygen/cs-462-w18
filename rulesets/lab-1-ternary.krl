ruleset lab_1 {
  meta {
    name "Lab 1"
    description <<
Events and Queries >>
    author "Xander Moffatt"
    logging on
    shares hello
  }
  
  global {
    hello = function(obj) {
      msg = "Hello " + obj;
      msg
    }
  }
  
  rule hello_world {
    select when echo hello
    send_directive("say", {"something": "Hello World"})
  }

  rule hello_monkey {
    select when echo monkey
    pre{
      name = event:attr("name").isnull() => "monkey" | event:attr("name")
    }
    send_directive("say", {"something": "Hello " + name})
    always{
      name.klog("Name passed in: ")
    }
  }
  
}