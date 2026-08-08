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
  mut initialized : Bool
  mut server_info : Implementation?
  mut negotiated_version : String?
  mut pending : Map[RequestId, RpcResponse]
  mut notifications : Array[RpcNotification]
}

///|
/// Create a new client advertising the given client name/version.
pub fn Client::new(name : String, version : String) -> Client {
  {
    client_info: { name, title: None, version },
    next_id: 1,
    initialized: false,
    server_info: None,
    negotiated_version: None,
    pending: Map([]),
    notifications: [],
  }
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

///|
/// Build a `resources/list` request, optionally continuing from a cursor.
pub fn Client::build_resources_list(
  self : Client,
  cursor : String?,
) -> (RequestId, String) {
  let params = match cursor {
    Some(c) => {
      let obj : Map[String, Json] = Map([])
      obj["cursor"] = Json::string(c)
      Some(Json::object(obj))
    }
    None => None
  }
  self.build_request(method_resources_list, params)
}

///|
/// Build a `resources/read` request for a concrete URI.
pub fn Client::build_resources_read(
  self : Client,
  uri : String,
) -> (RequestId, String) {
  let params : Map[String, Json] = Map([])
  params["uri"] = Json::string(uri)
  self.build_request(method_resources_read, Some(Json::object(params)))
}

///|
/// Build a `resources/subscribe` request for change notifications on a URI.
pub fn Client::build_resources_subscribe(
  self : Client,
  uri : String,
) -> (RequestId, String) {
  let params : Map[String, Json] = Map([])
  params["uri"] = Json::string(uri)
  self.build_request(method_resources_subscribe, Some(Json::object(params)))
}

///|
/// Build a `prompts/list` request, optionally continuing from a cursor.
pub fn Client::build_prompts_list(
  self : Client,
  cursor : String?,
) -> (RequestId, String) {
  let params = match cursor {
    Some(c) => {
      let obj : Map[String, Json] = Map([])
      obj["cursor"] = Json::string(c)
      Some(Json::object(obj))
    }
    None => None
  }
  self.build_request(method_prompts_list, params)
}

///|
/// Build a `prompts/get` request with a JSON object of string arguments.
pub fn Client::build_prompts_get(
  self : Client,
  name : String,
  arguments : Json,
) -> (RequestId, String) {
  let params : Map[String, Json] = Map([])
  params["name"] = Json::string(name)
  params["arguments"] = arguments
  self.build_request(method_prompts_get, Some(Json::object(params)))
}

///|
/// Build a `logging/setLevel` request.
pub fn Client::build_logging_set_level(
  self : Client,
  level : LogLevel,
) -> (RequestId, String) {
  let params : Map[String, Json] = Map([])
  params["level"] = Json::string(level.to_string())
  self.build_request(method_logging_set_level, Some(Json::object(params)))
}

///|
/// Encode a client notification without allocating a request id.
pub fn Client::build_notification(
  self : Client,
  method_name : String,
  params : Json?,
) -> String {
  ignore(self)
  message_to_string(MsgNotification({ method_name, params }))
}

///|
/// Build the `notifications/initialized` notification.
pub fn Client::build_initialized(self : Client) -> String {
  self.build_notification(method_initialized, None)
}

// ===================== Response handling =====================

///|
/// Extract the request id an [RpcResponse] is answering.
fn response_id(resp : RpcResponse) -> RequestId {
  match resp {
    RpcResult(id, _) => id
    RpcErrorResp(id, _) => id
  }
}

///|
/// Feed an inbound JSON-RPC message string to the client.
///
/// Responses are stored (keyed by id) for retrieval with [Client::take_result];
/// notifications are appended to the received list. Server-initiated requests
/// (e.g. sampling) are acknowledged but not yet answered.
pub fn Client::handle_message(
  self : Client,
  raw : String,
) -> Result[Unit, McpError] {
  match parse_message(raw) {
    Err(e) => Err(e)
    Ok(MsgResponse(resp)) => {
      self.pending[response_id(resp)] = resp
      Ok(())
    }
    Ok(MsgNotification(notif)) => {
      self.notifications.push(notif)
      Ok(())
    }
    Ok(MsgRequest(_)) => Ok(())
  }
}

///|
/// Retrieve and remove a stored response by id, returning its result JSON.
///
/// Fails if no response has arrived for that id yet, or if the server answered
/// with a JSON-RPC error.
pub fn Client::take_result(
  self : Client,
  id : RequestId,
) -> Result[Json, McpError] {
  let resp = match self.pending.get(id) {
    Some(r) => r
    None => return Err(ProtocolError("no response received for request id"))
  }
  self.pending.remove(id)
  match resp {
    RpcResult(_, result) => Ok(result)
    RpcErrorResp(_, err) => Err(RpcError(err.code, err.message))
  }
}

///|
/// Complete the initialize handshake from a raw initialize response string.
///
/// Records the server's [Implementation] and the negotiated protocol version,
/// then marks the client as initialized.
pub fn Client::complete_initialize(
  self : Client,
  raw : String,
) -> Result[Implementation, McpError] {
  let msg = match parse_message(raw) {
    Ok(m) => m
    Err(e) => return Err(e)
  }
  let result = match msg {
    MsgResponse(RpcResult(_, result)) => result
    MsgResponse(RpcErrorResp(_, err)) =>
      return Err(RpcError(err.code, err.message))
    _ => return Err(ProtocolError("expected an initialize response"))
  }
  self.complete_initialize_result(result)
}

///|
/// Complete the initialize handshake from an already-extracted `result` JSON
/// value (e.g. the initialize response after it was correlated by id through a
/// [ClientConnection]).
///
/// Records the server's [Implementation] and the negotiated protocol version,
/// then marks the client as initialized.
pub fn Client::complete_initialize_result(
  self : Client,
  result : Json,
) -> Result[Implementation, McpError] {
  let obj = match result {
    Object(o) => o
    _ => return Err(ProtocolError("initialize result must be an object"))
  }
  let version = match obj.get("protocolVersion") {
    Some(String(s)) => s
    _ => return Err(ProtocolError("initialize result missing protocolVersion"))
  }
  let server_obj = match obj.get("serverInfo") {
    Some(Object(si)) => si
    _ => return Err(ProtocolError("initialize result missing serverInfo"))
  }
  let info = match parse_implementation(server_obj) {
    Ok(i) => i
    Err(e) => return Err(e)
  }
  self.server_info = Some(info)
  self.negotiated_version = Some(version)
  self.initialized = true
  Ok(info)
}

///|
/// Parse an [Implementation] from a JSON object (name/title/version).
fn parse_implementation(
  obj : Map[String, Json],
) -> Result[Implementation, McpError] {
  let name = match obj.get("name") {
    Some(String(s)) => s
    _ => return Err(ProtocolError("implementation missing name"))
  }
  let title = match obj.get("title") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let version = match obj.get("version") {
    Some(String(s)) => s
    _ => ""
  }
  Ok({ name, title, version })
}

// ===================== State accessors =====================

///|
/// Whether the client has completed the initialize handshake.
pub fn Client::is_initialized(self : Client) -> Bool {
  self.initialized
}

///|
/// The server's [Implementation] learned during initialize, if any.
pub fn Client::server(self : Client) -> Implementation? {
  self.server_info
}

///|
/// The protocol version negotiated during initialize, if any.
pub fn Client::protocol_version(self : Client) -> String? {
  self.negotiated_version
}

///|
/// All server-initiated notifications received so far, in arrival order.
pub fn Client::received_notifications(self : Client) -> Array[RpcNotification] {
  self.notifications
}
