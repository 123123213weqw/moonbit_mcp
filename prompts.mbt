///|
/// A named argument accepted by a prompt.
pub(all) struct PromptArgument {
  name : String
  description : String?
  required : Bool
} derive(Debug, Eq)

///|
/// Role of a prompt message sender.
pub(all) enum PromptRole {
  RoleUser
  RoleAssistant
} derive(Debug, Eq)

///|
/// A single message in a prompt result.
pub(all) struct PromptMessage {
  role : PromptRole
  content : ContentBlock
} derive(Debug, Eq)

///|
/// A prompt definition registered on an MCP server.
pub(all) struct Prompt {
  name : String
  mut title : String?
  mut description : String?
  arguments : Array[PromptArgument]
} derive(Debug, Eq)

///|
/// Create a new prompt with the given name.
pub fn Prompt::new(name : String) -> Prompt {
  { name, title: None, description: None, arguments: [] }
}

///|
/// Set the optional display title of a prompt.
pub fn Prompt::with_title(self : Prompt, title : String) -> Prompt {
  self.title = Some(title)
  self
}

///|
/// Set the human-readable description of a prompt.
pub fn Prompt::describe(self : Prompt, description : String) -> Prompt {
  self.description = Some(description)
  self
}

///|
/// Add an argument to a prompt.
pub fn Prompt::arg(self : Prompt, name : String, required : Bool) -> Prompt {
  self.arguments.push({ name, description: None, required })
  self
}

///|
/// Add a described argument to a prompt.
pub fn Prompt::arg_desc(
  self : Prompt,
  name : String,
  description : String,
  required : Bool,
) -> Prompt {
  self.arguments.push({ name, description: Some(description), required })
  self
}

///|
/// Encode a [Prompt] to JSON.
pub fn Prompt::to_json(self : Prompt) -> Json {
  let obj : Map[String, Json] = Map([])
  obj["name"] = Json::string(self.name)
  match self.title {
    Some(t) => obj["title"] = Json::string(t)
    None => ()
  }
  match self.description {
    Some(d) => obj["description"] = Json::string(d)
    None => ()
  }
  obj["arguments"] = Json::array(
    self.arguments.map(fn(a) {
      let a_obj : Map[String, Json] = Map([])
      a_obj["name"] = Json::string(a.name)
      match a.description {
        Some(d) => a_obj["description"] = Json::string(d)
        None => ()
      }
      a_obj["required"] = if a.required {
        Json::boolean(true)
      } else {
        Json::boolean(false)
      }
      Json::object(a_obj)
    }),
  )
  Json::object(obj)
}

///|
/// Result of getting a prompt.
pub(all) struct GetPromptResult {
  mut description : String?
  messages : Array[PromptMessage]
} derive(Debug, Eq)

///|
/// Construct a prompt result from a sequence of messages.
pub fn GetPromptResult::new(messages : Array[PromptMessage]) -> GetPromptResult {
  { description: None, messages }
}

///|
/// Attach a human-readable description to a prompt result.
pub fn GetPromptResult::describe(
  self : GetPromptResult,
  description : String,
) -> GetPromptResult {
  self.description = Some(description)
  self
}

///|
/// Construct a user prompt message containing text.
pub fn PromptMessage::user(text : String) -> PromptMessage {
  { role: RoleUser, content: text_content(text) }
}

///|
/// Construct an assistant prompt message containing text.
pub fn PromptMessage::assistant(text : String) -> PromptMessage {
  { role: RoleAssistant, content: text_content(text) }
}

///|
/// Encode [GetPromptResult] to JSON.
pub fn GetPromptResult::to_json(self : GetPromptResult) -> Json {
  let obj : Map[String, Json] = Map([])
  match self.description {
    Some(d) => obj["description"] = Json::string(d)
    None => ()
  }
  obj["messages"] = Json::array(
    self.messages.map(fn(m) {
      let m_obj : Map[String, Json] = Map([])
      m_obj["role"] = Json::string(
        match m.role {
          RoleUser => "user"
          RoleAssistant => "assistant"
        },
      )
      m_obj["content"] = m.content.to_json()
      Json::object(m_obj)
    }),
  )
  Json::object(obj)
}
