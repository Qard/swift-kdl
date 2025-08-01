# Getting Started with KDL

Learn how to parse and generate KDL documents in Swift.

## Overview

This guide will walk you through the basics of using the KDL Swift package to work with KDL (Cuddly Data Language) documents.

## What is KDL?

KDL (Cuddly Data Language) is a document language that aims to be more human-readable and writable than alternatives like JSON or XML. Here's an example KDL document:

```kdl
// This is a node with a single argument
title "Hello, World!"

// This is a node with multiple arguments
coordinates 12.5 42.0 13.8

// This is a node with properties (key-value pairs)
author name="Jane Doe" email="jane@example.com"

// This is a node with both arguments and properties
image "logo.png" width=100 height=50

// This is a node with children
server {
    host "localhost"
    port 8080
    secure true
    
    routes {
        - "/api/v1"
        - "/health"
        - "/metrics"
    }
}
```

## Basic Parsing

To parse a KDL document, use the ``KDLParser`` class:

```swift
import KDL

let kdlText = """
name "my-application"
version "1.0.0"
enabled true
"""

let parser = KDLParser(input: kdlText)
let document = try parser.parseDocument()

// Access nodes by name
for node in document.nodes {
    print("Node: \(node.name)")
    for argument in node.arguments {
        print("  Argument: \(argument)")
    }
}
```

## Working with Node Data

``KDLNode`` objects contain:
- A name (identifier)
- Arguments (positional values)
- Properties (key-value pairs)
- Child nodes

```swift
let node = document.nodes.first { $0.name == "name" }
if let nameValue = node?.arguments.first?.stringValue {
    print("Application name: \(nameValue)")
}

// Access properties
let authorNode = document.nodes.first { $0.name == "author" }
if let email = authorNode?.property("email")?.stringValue {
    print("Author email: \(email)")
}
```

## Using Codable

The most convenient way to work with KDL is through Swift's `Codable` protocol:

```swift
struct AppConfig: Codable {
    let name: String
    let version: String
    let enabled: Bool
}

let decoder = KDLDecoder()
let config = try decoder.decode(AppConfig.self, from: kdlText)

print(config.name)    // "my-application"
print(config.version) // "1.0.0"
print(config.enabled) // true
```

## Generating KDL

You can also encode Swift types back to KDL:

```swift
let config = AppConfig(
    name: "my-application",
    version: "2.0.0",
    enabled: false
)

let encoder = KDLEncoder()
let kdlOutput = try encoder.encodeToString(config)
print(kdlOutput)
```

## Next Steps

- Learn about ``KDLDecoder`` and ``KDLEncoder`` configuration options
- Explore ``KDLFormatter`` for customizing output format
- Handle errors with ``KDLError``
- Work with different ``KDLVersion`` formats