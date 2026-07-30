name = "123123213weqw/moonbit_mcp"

version = "0.2.0"

readme = "README.md"

repository = "https://github.com/123123213weqw/moonbit_mcp"

license = "MIT"

keywords = [ "mcp", "model-context-protocol", "llm", "agent", "sdk" ]

preferred_target = "wasm-gc"

description = "A MoonBit SDK for the Model Context Protocol (MCP). Build MCP servers and clients in MoonBit."

options(
  exclude: [
    ".github",
    ".gitignore",
    "AGENTS.md",
    "docs",
    "examples",
    "scripts",
    "tests",
    "*_wbtest.mbt",
  ],
)
