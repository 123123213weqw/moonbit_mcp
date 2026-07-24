///|
/// JSON-RPC 2.0 standard error code: parse error.
pub let parse_error_code : Int = -32700

///|
/// JSON-RPC 2.0 standard error code: invalid request.
pub let invalid_request_code : Int = -32600

///|
/// JSON-RPC 2.0 standard error code: method not found.
pub let method_not_found_code : Int = -32601

///|
/// JSON-RPC 2.0 standard error code: invalid params.
pub let invalid_params_code : Int = -32602

///|
/// JSON-RPC 2.0 standard error code: internal error.
pub let internal_error_code : Int = -32603

///|
/// Start of the implementation-defined error range.
pub let implementation_error_start : Int = -32000

///|
/// Resource not found error code (de-facto standard in MCP ecosystem).
pub let resource_not_found_code : Int = -32002

///|
/// Error type returned by all MCP SDK operations that can fail.
pub(all) enum McpError {
  RpcError(Int, String)
  ParseError(String)
  TransportError(String)
  ProtocolError(String)
  UnknownMethod(String)
  UnknownTarget(String)
  InvalidArguments(String)
} derive(Debug, Eq)

///|
/// Convert an [McpError] to a JSON-RPC error code.
pub fn McpError::to_code(self : McpError) -> Int {
  match self {
    RpcError(code, _) => code
    ParseError(_) => parse_error_code
    ProtocolError(_) => invalid_request_code
    UnknownMethod(_) => method_not_found_code
    UnknownTarget(_) | InvalidArguments(_) => invalid_params_code
    TransportError(_) => internal_error_code
  }
}

///|
/// Human-readable message for an [McpError].
pub fn McpError::to_message(self : McpError) -> String {
  match self {
    RpcError(_, msg) => msg
    ParseError(detail) => "Parse error: " + detail
    ProtocolError(detail) => "Protocol error: " + detail
    UnknownMethod(m) => "Method not found: " + m
    UnknownTarget(name) => "Unknown target: " + name
    InvalidArguments(detail) => "Invalid params: " + detail
    TransportError(detail) => "Transport error: " + detail
  }
}
