///|
/// A low-level MCP client: builds JSON-RPC requests with fresh ids and tracks
/// the session state negotiated with a server.
///
/// The client is transport-agnostic. Drive it by sending the strings returned
/// from the `build_*` methods through a [Transport], and feed inbound messages
/// back in (response handling is added on top of this core).
pub(all) struct Client {
  client_info : Implementation
  mut next_id : Int
}

///|
/// Create a new client advertising the given client name/version.
pub fn Client::new(name : String, version : String) -> Client {
  { client_info: { name, title: None, version }, next_id: 1 }
}

///|
/// The [Implementation] this client advertises during initialize.
pub fn Client::info(self : Client) -> Implementation {
  self.client_info
}

///|
/// Allocate the next request id (monotonically increasing integers).
fn Client::alloc_id(self : Client) -> RequestId {
  let id = IdInt(self.next_id)
  self.next_id = self.next_id + 1
  id
}

///|
/// Build a JSON-RPC request for the given method/params, returning the assigned
/// id alongside the serialized message so callers can correlate the response.
pub fn Client::build_request(
  self : Client,
  method_name : String,
  params : Json?,
) -> (RequestId, String) {
  let id = self.alloc_id()
  let req : RpcRequest = { id, method_name, params }
  (id, message_to_string(MsgRequest(req)))
}

///|
/// Build the `initialize` request that opens an MCP session.
pub fn Client::build_initialize(self : Client) -> (RequestId, String) {
  let params_obj : Map[String, Json] = Map([])
  params_obj["protocolVersion"] = Json::string(latest_protocol_version)
  params_obj["capabilities"] = Json::empty_object()
  params_obj["clientInfo"] = self.client_info.to_json()
  self.build_request(method_initialize, Some(Json::object(params_obj)))
}

///|
/// Build a `ping` request.
pub fn Client::build_ping(self : Client) -> (RequestId, String) {
  self.build_request(method_ping, None)
}

///|
/// Build a `tools/list` request.
pub fn Client::build_tools_list(self : Client) -> (RequestId, String) {
  self.build_request(method_tools_list, None)
}

///|
/// Build a `tools/call` request for the named tool with the given arguments.
pub fn Client::build_tools_call(
  self : Client,
  name : String,
  arguments : Json,
) -> (RequestId, String) {
  let params_obj : Map[String, Json] = Map([])
  params_obj["name"] = Json::string(name)
  params_obj["arguments"] = arguments
  self.build_request(method_tools_call, Some(Json::object(params_obj)))
}
