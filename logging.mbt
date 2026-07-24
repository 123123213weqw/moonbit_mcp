///|
/// Log severity level (RFC 5424 syslog ordering, low to high).
pub(all) enum LogLevel {
  LevelDebug
  LevelInfo
  LevelNotice
  LevelWarning
  LevelError
  LevelCritical
  LevelAlert
  LevelEmergency
} derive(Debug, Eq)

///|
/// Convert a [LogLevel] to its JSON string representation.
pub fn LogLevel::to_string(self : LogLevel) -> String {
  match self {
    LevelDebug => "debug"
    LevelInfo => "info"
    LevelNotice => "notice"
    LevelWarning => "warning"
    LevelError => "error"
    LevelCritical => "critical"
    LevelAlert => "alert"
    LevelEmergency => "emergency"
  }
}

///|
/// A log message notification sent from server to client.
pub(all) struct LogMessage {
  level : LogLevel
  logger : String?
  data : Json
} derive(Debug, Eq)

///|
/// Encode a [LogMessage] to a JSON notification params object.
pub fn LogMessage::to_json(self : LogMessage) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["level"] = Json::string(self.level.to_string())
  match self.logger {
    Some(l) => obj["logger"] = Json::string(l)
    None => ()
  }
  obj["data"] = self.data
  Json::object(obj)
}
