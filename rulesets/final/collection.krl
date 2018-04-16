ruleset final.collection {
  meta {
    shares __testing, n_kids, child_name, children
    use module io.picolabs.wrangler alias wrangler
  }
  global {
    __testing = { 
      "queries": [ 
        { "name": "__testing" },
        { "name": "n_kids" },
        { "name": "child_name" },
        { "name": "children" }
      ],
      "events": [ 
        {
          "domain": "collection",
          "type": "config",
          "attrs": [
            "child_name"
          ]
        },
        {
          "domain": "collection",
          "type": "create",
          "attrs": [
            "n"
          ]
        },
        {
          "domain": "collection",
          "type": "delete_some",
          "attrs": [
            "n"
          ]
        },
        {
          "domain": "collection",
          "type": "delete"
        }
      ] 
    }
    
    n_kids = function() { ent:n_kids }
    child_name = function() { ent:name }
    
    // this is needed because `wrangler:children()` is super janky and 
    // sometimes returns that children still exist, even though they've
    // been deleted
    children = function() {
      ent:n_kids > 0 => 
        wrangler:children().slice(ent:n_kids-1) | []
    }
    
    n_children = function(n) {
      children().slice(n-1).map(function(child) { child{"name"} })
    }
                  
    create_n_children = defaction(n, n_kids) {
      if n > 0 then 
        every {
          create_child(n_kids)
          create_n_children(n-1, n_kids+1)
        }
    }
    
    create_child = defaction(n) {
      attrs = {
        "name": ent:name + ":" + n
      }
      every {
        event:send({
          "eci":meta:eci, 
          "domain":"wrangler", 
          "type":"child_creation", 
          "attrs":attrs
        })
      }
    }
    
    delete_child = defaction(name) {
      event:send({ 
        "eci": meta:eci, 
        "eid": "delete",
        "domain": "wrangler", 
        "type": "child_deletion",
        "attrs": {
          "name": name
        }
      })
    }
  }
  
  rule intialization {
    select when wrangler ruleset_added where rids >< meta:rid
    always {
      raise collection event "config"
    }
  }
  
  rule set_vars {
    select when collection config
    pre {
      name = event:attr("child_name")
    }
    always {
      ent:name := name.defaultsTo("Child");
      ent:n_kids := 0;
    }
  }
  
  rule create_children {
    select when collection create
    pre {
      n = event:attr("n").as("Number").defaultsTo(1)
    }
    create_n_children(n, ent:n_kids)
    always {
      ent:n_kids := ent:n_kids + n
    }
  }
  
  rule delete_some_children {
    select when collection delete_some
    foreach n_children(event:attr("n").as("Number").defaultsTo(1)) setting (child)
      delete_child(child)
    always {
      ent:n_kids := ent:n_kids - event:attr("n").as("Number").defaultsTo(1) on final
    }
  }
  
  rule delete_all_children {
    select when collection delete
    foreach n_children(ent:n_kids) setting (child)
      delete_child(child)
    always {
      ent:n_kids := 0 on final
    }
  }
}
