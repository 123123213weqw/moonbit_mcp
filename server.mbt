///|
/// A handler function for a specific MCP method on a server.
///
/// Receives the raw JSON params (or Null) and returns either a result Json
/// or an [McpError].
pub type MethodHandler = (Json, ServerContext) -> Result[Json, McpError]

///|
/// Mutable server state passed to method handlers.
pub(all) struct ServerContext {
  server_info : Implementation
  capabilities : ServerCapabilities
  initialized : Bool
}

///|
/// The low-level MCP server: dispatches JSON-RPC messages to registered handlers
/// and manages the initialize handshake.
pub(all) struct Server {
  server_info : Implementation
  mut capabilities : ServerCapabilities
  mut handlers : Map[String, MethodHandler]
  mut initialized : Bool
}

///|
/// Create a new server with the given name/version and default (empty) capabilities.
pub fn Server::new(name : String, version : String) -> Server {
  {
    server_info: { name, title: None, version },
    capabilities: ServerCapabilities::new(),
    handlers: Map([]),
    initialized: false,
  }
}

///|
/// Register a handler for a specific MCP method.
pub fn Server::handle_method(
  self : Server,
  m : String,
  h : MethodHandler,
) -> Server {
  self.handlers[m] = h
  self
}

///|
/// Enable tools capability with list-changed notifications.
pub fn Server::with_tools(self : Server) -> Server {
  self.capabilities.tools_list_changed = true
  self
}

///|
/// Enable resources discovery, reads, and list-changed notifications.
pub fn Server::with_resources(self : Server) -> Server {
  self.capabilities.resources_list_changed = true
  self
}

///|
/// Enable prompt discovery, retrieval, and list-changed notifications.
pub fn Server::with_prompts(self : Server) -> Server {
  self.capabilities.prompts_list_changed = true
  self
}

///|
/// Process a single incoming JSON-RPC message string and return the response
/// string (if any — notifications produce no response).
pub fn Server::process_message(self : Server, raw : String) -> String? {
  match parse_message(raw) {
    Err(e) => {
      let err_resp : RpcResponse = RpcErrorResp(IdInt(0), {
        code: e.to_code(),
        message: e.to_message(),
        data: None,
      })
      Some(message_to_string(MsgResponse(err_resp)))
    }
    Ok(MsgNotification(notif)) => {
      match notif.method_name {
        m if m == method_initialized => {
          self.initialized = true
          ()
        }
        _ => ()
      }
      None
    }
    Ok(MsgRequest(req)) => {
      let resp = self.dispatch_request(req)
      Some(message_to_string(MsgResponse(resp)))
    }
    Ok(MsgResponse(_)) => None
  }
}

///|
fn Server::dispatch_request(self : Server, req : RpcRequest) -> RpcResponse {
  let ctx : ServerContext = {
    server_info: self.server_info,
    capabilities: self.capabilities,
    initialized: self.initialized,
  }
  let m = req.method_name
  if m == method_initialize {
    self.handle_initialize(req, ctx)
  } else if m == method_ping {
    RpcResult(req.id, Json::empty_object())
  } else {
    match self.handlers.get(m) {
      Some(h) => {
        let params = match req.params {
          Some(p) => p
          None => Json::null()
        }
        match h(params, ctx) {
          Ok(result) => RpcResult(req.id, result)
          Err(e) =>
            RpcErrorResp(req.id, {
              code: e.to_code(),
              message: e.to_message(),
              data: None,
            })
        }
      }
      None =>
        RpcErrorResp(req.id, {
          code: method_not_found_code,
          message: "Method not found: " + m,
          data: None,
        })
    }
  }
}

///|
fn Server::handle_initialize(
  self : Server,
  req : RpcRequest,
  _ctx : ServerContext,
) -> RpcResponse {
  let result_obj : Map[String, Json] = Map([])
  result_obj["protocolVersion"] = Json::string(latest_protocol_version)
  result_obj["capabilities"] = self.capabilities.to_json()
  result_obj["serverInfo"] = self.server_info.to_json()
  RpcResult(req.id, Json::object(result_obj))
}
