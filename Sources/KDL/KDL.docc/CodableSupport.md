# Codable Support

Use Swift's Codable protocol to seamlessly work with KDL documents.

## Overview

The KDL package provides full support for Swift's `Codable` protocol through ``KDLDecoder`` and ``KDLEncoder``. This allows you to work with KDL documents using familiar Swift patterns.

## Basic Decoding

```swift
struct ServerConfig: Codable {
    let host: String
    let port: Int
    let secure: Bool
}

let kdl = """
host "localhost"
port 8080
secure true
"""

let decoder = KDLDecoder()
let config = try decoder.decode(ServerConfig.self, from: kdl)
```

## Nested Structures

KDL's nested structure maps naturally to Swift's nested types:

```swift
struct AppConfig: Codable {
    let name: String
    let version: String
    let server: ServerConfig
    let database: DatabaseConfig
}

struct DatabaseConfig: Codable {
    let url: String
    let poolSize: Int
}

let kdl = """
name "my-app"
version "1.0.0"
server {
    host "localhost"
    port 8080
    secure true
}
database {
    url "postgresql://localhost/mydb"
    poolSize 10
}
"""

let config = try decoder.decode(AppConfig.self, from: kdl)
```

## Arrays

Arrays can be represented in KDL as child nodes with "-" names:

```swift
struct Config: Codable {
    let tags: [String]
    let ports: [Int]
}

let kdl = """
tags {
    - "swift"
    - "kdl"
    - "parser"
}
ports {
    - 8080
    - 8081
    - 8082
}
"""

let config = try decoder.decode(Config.self, from: kdl)
```

## Custom Key Mapping

Use `CodingKeys` to map between Swift property names and KDL node names:

```swift
struct PersonConfig: Codable {
    let firstName: String
    let lastName: String
    let emailAddress: String
    
    enum CodingKeys: String, CodingKey {
        case firstName = "first-name"
        case lastName = "last-name" 
        case emailAddress = "email-address"
    }
}

let kdl = """
first-name "John"
last-name "Doe"
email-address "john@example.com"
"""

let person = try decoder.decode(PersonConfig.self, from: kdl)
```

## Encoding Options

``KDLEncoder`` provides several configuration options:

```swift
let encoder = KDLEncoder()

// Array encoding strategy
encoder.arrayEncodingStrategy = .childNodes // Default
// or
encoder.arrayEncodingStrategy = .arguments

// Nil value handling
encoder.nilEncodingStrategy = .includeAsNull // Default
// or
encoder.nilEncodingStrategy = .omit

// Key encoding
encoder.keyEncodingStrategy = .useDefaultKeys // Default
// or
encoder.keyEncodingStrategy = .convertToKebabCase
```

## Special Values

KDL supports special floating-point values:

```swift
struct FloatConfig: Codable {
    let positive: Double
    let negative: Double
    let notANumber: Double
}

let config = FloatConfig(
    positive: .infinity,
    negative: -.infinity,
    notANumber: .nan
)

let encoder = KDLEncoder()
let kdl = try encoder.encodeToString(config)
// Output includes #inf, #-inf, #nan

let decoder = KDLDecoder()
decoder.nonConformingFloatDecodingStrategy = .convertFromString(
    positiveInfinity: "#inf",
    negativeInfinity: "#-inf",
    nan: "#nan"
)
let decoded = try decoder.decode(FloatConfig.self, from: kdl)
```

## Format Preservation

You can preserve the original formatting when round-tripping documents:

```swift
let decoder = KDLDecoder()
decoder.preservesFormat = true

let config = try decoder.decode(MyConfig.self, from: originalKDL)

// Create encoder with preserved format context
let encoder = decoder.createEncoder()
let formattedKDL = try encoder.encodeToString(config)
// Maintains original formatting where possible
```