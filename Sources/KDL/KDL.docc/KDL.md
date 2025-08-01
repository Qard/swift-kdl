# ``KDL``

A Swift package for parsing and generating KDL (Cuddly Data Language) documents.

## Overview

KDL (Cuddly Data Language) is a document language with a focus on human readability and writability. This Swift package provides a complete implementation for parsing KDL documents into Swift data structures and encoding Swift types back to KDL format.

### Key Features

- **Full KDL Specification Support**: Supports both KDL 1.x and 2.x with automatic version detection
- **Swift Codable Integration**: Seamlessly encode and decode Swift types using familiar `Codable` protocols
- **Comprehensive Parsing**: Handles all KDL features including nested structures, type annotations, and special values
- **Format Preservation**: Optional format preservation for maintaining original document styling
- **Error Reporting**: Detailed error messages with source location information

### Quick Start

```swift
import KDL

// Parse a KDL document
let kdl = """
name "my-app"
version "1.0.0"
server {
    host "localhost"
    port 8080
    secure true
}
"""

let parser = KDLParser(input: kdl)
let document = try parser.parseDocument()

// Access nodes
let nameNode = document.nodes.first { $0.name == "name" }
print(nameNode?.arguments.first?.stringValue) // "my-app"

// Use with Codable
struct Config: Codable {
    let name: String
    let version: String
    let server: ServerConfig
}

struct ServerConfig: Codable {
    let host: String
    let port: Int
    let secure: Bool
}

let decoder = KDLDecoder()
let config = try decoder.decode(Config.self, from: kdl)
```

## Topics

### Parsing Documents

- ``KDLParser``
- ``KDLDocument``
- ``KDLNode``
- ``KDLValue``

### Codable Support

- ``KDLDecoder``
- ``KDLEncoder``

### Document Structure

- ``KDLTypeAnnotation``
- ``KDLSourceLocation``

### Formatting

- ``KDLFormatter``
- ``KDLFormatOptions``
- ``KDLFormatContext``

### Version Support

- ``KDLVersion``

### Error Handling

- ``KDLError``

### Lexical Analysis

- ``KDLLexer``
- ``KDLToken``
- ``KDLTokenType``