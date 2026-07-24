///|
/// Audience for a content block annotation.
pub(all) enum Audience {
  AudienceUser
  AudienceAssistant
} derive(Debug, Eq)

///|
/// Annotations providing hints about a content block's role.
pub(all) struct ContentAnnotations {
  audience : Array[Audience]
  priority : Double?
  last_modified : String?
} derive(Debug, Eq)

///|
/// Contents of a resource — either text or base64 blob.
pub(all) enum ResourceContents {
  TextResourceContents(String, String?, String)
  BlobResourceContents(String, String?, String)
} derive(Debug, Eq)

///|
/// A content block — the universal payload type shared by tools, resources, and prompts.
pub(all) enum ContentBlock {
  /// Plain text content.
  TextContent(String, ContentAnnotations?)
  /// Base64-encoded image data with a MIME type.
  ImageContent(String, String, ContentAnnotations?)
  /// Base64-encoded audio data with a MIME type.
  AudioContent(String, String, ContentAnnotations?)
  /// A link to a resource identified by URI.
  ResourceLink(String, String, String?, String?, String?, ContentAnnotations?)
  /// An embedded resource (text or blob).
  EmbeddedResource(ResourceContents, ContentAnnotations?)
} derive(Debug, Eq)

///|
/// Convenience constructor: create a text content block with no annotations.
pub fn text_content(text : String) -> ContentBlock {
  TextContent(text, None)
}

///|
/// Extract the text from a [ContentBlock] if it is a text block.
pub fn ContentBlock::as_text(self : ContentBlock) -> String? {
  match self {
    TextContent(t, _) => Some(t)
    _ => None
  }
}

///|
/// Encode [ResourceContents] to JSON.
pub fn ResourceContents::to_json(self : ResourceContents) -> Json {
  let obj : Map[String, Json] = Map([])
  match self {
    TextResourceContents(uri, mime, text) => {
      obj["uri"] = Json::string(uri)
      match mime {
        Some(m) => obj["mimeType"] = Json::string(m)
        None => ()
      }
      obj["text"] = Json::string(text)
    }
    BlobResourceContents(uri, mime, blob) => {
      obj["uri"] = Json::string(uri)
      match mime {
        Some(m) => obj["mimeType"] = Json::string(m)
        None => ()
      }
      obj["blob"] = Json::string(blob)
    }
  }
  Json::object(obj)
}

///|
/// Encode a [ContentBlock] to JSON.
pub fn ContentBlock::to_json(self : ContentBlock) -> Json {
  let obj : Map[String, Json] = Map([])
  match self {
    TextContent(text, _ann) => {
      obj["type"] = Json::string("text")
      obj["text"] = Json::string(text)
    }
    ImageContent(data, mime, _ann) => {
      obj["type"] = Json::string("image")
      obj["data"] = Json::string(data)
      obj["mimeType"] = Json::string(mime)
    }
    AudioContent(data, mime, _ann) => {
      obj["type"] = Json::string("audio")
      obj["data"] = Json::string(data)
      obj["mimeType"] = Json::string(mime)
    }
    ResourceLink(uri, name, title, desc, mime, _ann) => {
      obj["type"] = Json::string("resource_link")
      obj["uri"] = Json::string(uri)
      obj["name"] = Json::string(name)
      match title {
        Some(t) => obj["title"] = Json::string(t)
        None => ()
      }
      match desc {
        Some(d) => obj["description"] = Json::string(d)
        None => ()
      }
      match mime {
        Some(m) => obj["mimeType"] = Json::string(m)
        None => ()
      }
    }
    EmbeddedResource(contents, _ann) => {
      obj["type"] = Json::string("resource")
      obj["resource"] = contents.to_json()
    }
  }
  Json::object(obj)
}

///|
/// Encode an array of content blocks to a JSON array.
pub fn content_blocks_to_json(blocks : Array[ContentBlock]) -> Json {
  Json::array(blocks.map(fn(b) { b.to_json() }))
}
