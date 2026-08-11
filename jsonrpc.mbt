///|
/// JSON-RPC 2.0 protocol version string.
pub let json_rpc_version : String = "2.0"

///|
/// A JSON-RPC request id. Per MCP spec, id must be string or integer, never null.
pub(all) enum RequestId {
  IdInt(Int)
  IdString(String)
} derive(Debug, Eq, Hash)

///|
/// JSON-RPC error object.
pub(all) struct RpcErrorObject {
  code : Int
  message : String
  data : Json?
} derive(Debug, Eq)

///|
/// A JSON-RPC request.
pub(all) struct RpcRequest {
  id : RequestId
  method_name : String
  params : Json?
} derive(Debug, Eq)

///|
/// A JSON-RPC response (result or error, mutually exclusive).
pub(all) enum RpcResponse {
  RpcResult(RequestId, Json)
  RpcErrorResp(RequestId, RpcErrorObject)
} derive(Debug, Eq)

///|
/// A JSON-RPC notification (no id, no response expected).
pub(all) struct RpcNotification {
  method_name : String
  params : Json?
} derive(Debug, Eq)

///|
/// Sum type for any inbound JSON-RPC message.
pub(all) enum RpcMessage {
  MsgRequest(RpcRequest)
  MsgResponse(RpcResponse)
  MsgNotification(RpcNotification)
} derive(Debug, Eq)

// ===================== Encoding =====================

///|
fn RequestId::to_json(self : RequestId) -> Json {
  match self {
    IdInt(n) => Json::number(n.to_double())
    IdString(s) => Json::string(s)
  }
}

///|
/// The method string of a request.
pub fn RpcRequest::method_str(self : RpcRequest) -> String {
  self.method_name
}

///|
/// The method string of a notification.
pub fn RpcNotification::method_str(self : RpcNotification) -> String {
  self.method_name
}

///|
/// Encode an [RpcRequest] to a JSON object.
pub fn RpcRequest::to_json(self : RpcRequest) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["jsonrpc"] = Json::string(json_rpc_version)
  obj["id"] = self.id.to_json()
  obj["method"] = Json::string(self.method_name)
  match self.params {
    Some(p) => obj["params"] = p
    None => ()
  }
  Json::object(obj)
}

///|
/// Encode an [RpcResponse] to a JSON object.
pub fn RpcResponse::to_json(self : RpcResponse) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["jsonrpc"] = Json::string(json_rpc_version)
  match self {
    RpcResult(id, result) => {
      obj["id"] = id.to_json()
      obj["result"] = result
    }
    RpcErrorResp(id, err) => {
      obj["id"] = id.to_json()
      let err_obj : Map[String, Json] = Map([])
      err_obj["code"] = Json::number(err.code.to_double())
      err_obj["message"] = Json::string(err.message)
      match err.data {
        Some(d) => err_obj["data"] = d
        None => ()
      }
      obj["error"] = Json::object(err_obj)
    }
  }
  Json::object(obj)
}

///|
/// Encode an [RpcNotification] to a JSON object.
pub fn RpcNotification::to_json(self : RpcNotification) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["jsonrpc"] = Json::string(json_rpc_version)
  obj["method"] = Json::string(self.method_name)
  match self.params {
    Some(p) => obj["params"] = p
    None => ()
  }
  Json::object(obj)
}

// ===================== Decoding =====================

///|
/// Parse a [RequestId] from a JSON value.
fn parse_id(j : Json) -> Result[RequestId, McpError] {
  match j {
    Number(n, ..) => {
      let i = n.to_int()
      if n == i.to_double() {
        Ok(IdInt(i))
      } else {
        Err(ParseError("request id must be integer or string"))
      }
    }
    String(s) => Ok(IdString(s))
    _ => Err(ParseError("request id must be integer or string"))
  }
}

///|
/// Parse an [RpcMessage] from a raw JSON string.
pub fn parse_message(raw : String) -> Result[RpcMessage, McpError] {
  let parsed = @json.parse(raw) catch {
    _ => return Err(ParseError("invalid JSON"))
  }
  match parsed {
    Object(obj) => {
      // Every JSON-RPC message carries the literal protocol version.
      match obj.get("jsonrpc") {
        Some(String(v)) if v == json_rpc_version => ()
        Some(String(_)) => return Err(ParseError("jsonrpc must be '2.0'"))
        _ => return Err(ParseError("jsonrpc must be a string"))
      }
      // A present method distinguishes requests/notifications from responses.
      match obj.get("method") {
        Some(String(m_name)) => {
          let params : Json? = match obj.get("params") {
            None => None
            Some(Object(p)) => Some(Json::object(p))
            Some(Array(p)) => Some(Json::array(p))
            Some(_) =>
              return Err(ParseError("params must be an object or array"))
          }
          match obj.get("id") {
            None => Ok(MsgNotification({ method_name: m_name, params }))
            Some(id_val) =>
              match parse_id(id_val) {
                Ok(id) => Ok(MsgRequest({ id, method_name: m_name, params }))
                Err(e) => Err(e)
              }
          }
        }
        Some(_) => Err(ParseError("method must be a string"))
        None => {
          // A response must have an id and exactly one of result/error.
          let id = match obj.get("id") {
            Some(id_val) =>
              match parse_id(id_val) {
                Ok(i) => i
                Err(e) => return Err(e)
              }
            None => return Err(ParseError("response must contain id"))
          }
          let result = obj.get("result")
          let error = obj.get("error")
          match (result, error) {
            (Some(_), Some(_)) =>
              Err(ParseError("response cannot contain both result and error"))
            (None, None) =>
              Err(ParseError("response must contain result or error"))
            (Some(result), None) => Ok(MsgResponse(RpcResult(id, result)))
            (None, Some(Object(err_obj))) => {
              let code = match err_obj.get("code") {
                Some(Number(n, ..)) => {
                  let i = n.to_int()
                  if n != i.to_double() {
                    return Err(ParseError("error.code must be an integer"))
                  }
                  i
                }
                _ => return Err(ParseError("error.code must be number"))
              }
              let message = match err_obj.get("message") {
                Some(String(s)) => s
                _ => return Err(ParseError("error.message must be string"))
              }
              let data = err_obj.get("data")
              Ok(MsgResponse(RpcErrorResp(id, { code, message, data })))
            }
            (None, Some(_)) => Err(ParseError("error must be an object"))
          }
        }
      }
    }
    _ => Err(ParseError("JSON-RPC message must be an object"))
  }
}

///|
/// Serialize any [RpcMessage] to a JSON string.
pub fn message_to_string(msg : RpcMessage) -> String {
  let j = match msg {
    MsgRequest(req) => req.to_json()
    MsgResponse(resp) => resp.to_json()
    MsgNotification(notif) => notif.to_json()
  }
  j.stringify()
}
