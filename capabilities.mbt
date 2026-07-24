///|
/// Server-side capability flags (each optional; advertised in initialize response).
pub(all) struct ServerCapabilities {
  mut tools_list_changed : Bool
  mut resources_subscribe : Bool
  mut resources_list_changed : Bool
  mut prompts_list_changed : Bool
  mut logging : Bool
} derive(Debug, Eq)

///|
/// Default capabilities: everything off. Use the builder methods to enable.
pub fn ServerCapabilities::new() -> ServerCapabilities {
  {
    tools_list_changed: false,
    resources_subscribe: false,
    resources_list_changed: false,
    prompts_list_changed: false,
    logging: false,
  }
}

///|
/// Encode [ServerCapabilities] to the JSON capabilities object.
pub fn ServerCapabilities::to_json(self : ServerCapabilities) -> Json {
  let obj : Map[String, Json] = Map([])
  if self.tools_list_changed {
    let tools_obj : Map[String, Json] = Map([])
    tools_obj["listChanged"] = Json::boolean(true)
    obj["tools"] = Json::object(tools_obj)
  }
  if self.resources_subscribe || self.resources_list_changed {
    let res_obj : Map[String, Json] = Map([])
    res_obj["subscribe"] = if self.resources_subscribe {
      Json::boolean(true)
    } else {
      Json::null()
    }
    res_obj["listChanged"] = if self.resources_list_changed {
      Json::boolean(true)
    } else {
      Json::null()
    }
    obj["resources"] = Json::object(res_obj)
  }
  if self.prompts_list_changed {
    let p_obj : Map[String, Json] = Map([])
    p_obj["listChanged"] = Json::boolean(true)
    obj["prompts"] = Json::object(p_obj)
  }
  if self.logging {
    obj["logging"] = Json::empty_object()
  }
  Json::object(obj)
}
