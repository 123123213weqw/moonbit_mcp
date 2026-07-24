///|
/// The latest MCP protocol version this SDK targets.
pub let latest_protocol_version : String = "2025-06-18"

///|
/// Name and version of a client or server implementation.
pub(all) struct Implementation {
  name : String
  title : String?
  version : String
} derive(Debug, Eq)

///|
/// Encode [Implementation] to JSON.
pub fn Implementation::to_json(self : Implementation) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["name"] = Json::string(self.name)
  match self.title {
    Some(t) => obj["title"] = Json::string(t)
    None => ()
  }
  obj["version"] = Json::string(self.version)
  Json::object(obj)
}

///|
/// MCP method name constants.
pub let method_initialize : String = "initialize"

///|
pub let method_initialized : String = "notifications/initialized"

///|
pub let method_ping : String = "ping"

///|
pub let method_tools_list : String = "tools/list"

///|
pub let method_tools_call : String = "tools/call"

///|
pub let method_tools_list_changed : String = "notifications/tools/list_changed"

///|
pub let method_resources_list : String = "resources/list"

///|
pub let method_resources_read : String = "resources/read"

///|
pub let method_resources_templates_list : String = "resources/templates/list"

///|
pub let method_resources_subscribe : String = "resources/subscribe"

///|
pub let method_resources_updated : String = "notifications/resources/updated"

///|
pub let method_resources_list_changed : String = "notifications/resources/list_changed"

///|
pub let method_prompts_list : String = "prompts/list"

///|
pub let method_prompts_get : String = "prompts/get"

///|
pub let method_prompts_list_changed : String = "notifications/prompts/list_changed"

///|
pub let method_logging_set_level : String = "logging/setLevel"

///|
pub let method_logging_message : String = "notifications/message"

///|
pub let method_cancelled : String = "notifications/cancelled"

///|
pub let method_progress : String = "notifications/progress"
