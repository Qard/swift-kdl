# Swift KDL

A Swift implementation of the KDL (Cuddly Data Language) document format, supporting both KDL 1.x and 2.x specifications with automatic version detection.

## Features

- **Dual version support** (KDL 1.x and 2.x) with automatic detection
- **Complete KDL 2.0 language support** including all new features
- **Swift Codable integration** for easy serialization/deserialization
- **Type-safe API** with comprehensive error handling
- **Format preservation** for document editing
- **Full Unicode support** including KDL 2.0 whitespace characters
- **Extensive test coverage** (89 tests, 100% passing)

## Installation

### Swift Package Manager

Add this to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/swift-kdl.git", from: "2.0.0")
]
```

## Usage

### Basic Parsing

```swift
import KDL

let kdl = """
title "Hello, World!"
author "Jane Doe" email="jane@example.com"
"""

let document = try KDLParser.parse(kdl)
print(document.nodes[0].arguments[0]) // .string("Hello, World!")
```

### Version Support

The library automatically detects whether a document uses KDL 1.x or 2.x syntax:

```swift
// KDL 1.x format (auto-detected)
let kdl1 = "enabled true"

// KDL 2.x format (auto-detected)
let kdl2 = "enabled #true"

// Or specify a version explicitly
let document = try KDLParser.parse(kdl, version: .v2)
```

### Using Codable

```swift
struct Config: Codable {
    let title: String
    let author: String
    let enabled: Bool
}

// Decode from KDL
let decoder = KDLDecoder()
let config = try decoder.decode(Config.self, from: kdl)

// Encode to KDL
let encoder = KDLEncoder()
encoder.version = .v2  // Output KDL 2.x format
let output = try encoder.encodeToString(config)
```

### Version Differences

#### Boolean and Null Values
- **KDL 1.x**: `true`, `false`, `null`
- **KDL 2.x**: `#true`, `#false`, `#null`

```swift
// The library handles both formats automatically
let kdl1 = "setting true"     // KDL 1.x
let kdl2 = "setting #true"    // KDL 2.x
```

#### Reserved Identifiers
In KDL 2.x, `true`, `false`, and `null` are reserved and must be quoted when used as identifiers:

```swift
// KDL 2.x will quote these when formatting
let doc = KDLDocument(nodes: [
    KDLNode(name: "true"),   // Formatted as: "true"
    KDLNode(name: "custom")  // Formatted as: custom
])
```

### Advanced Features

#### Unicode Whitespace
KDL 2.0 supports various Unicode whitespace characters:

```swift
// All of these are valid whitespace in KDL 2.0
let spaces = "\u{0020}"  // Space
let nbsp = "\u{00A0}"    // No-Break Space  
let emSpace = "\u{2003}" // Em Space
// ... and many more
```

#### Version Markers
Documents can include optional version markers:

```kdl
/- kdl-version 2
title "My Document"
```

#### Format Preservation
When editing documents, formatting can be preserved:

```swift
let decoder = KDLDecoder()
decoder.preservesFormat = true
let data = try decoder.decode(MyType.self, from: kdl)

// Edit and re-encode while preserving format
let encoder = decoder.createEncoder()
let output = try encoder.encodeToString(modifiedData)
```

## Supported KDL Features

### Values
- ✅ Strings (quoted, multi-line, raw)
- ✅ Numbers (integers, decimals, hex, octal, binary)
- ✅ Booleans (`true`/`false` and `#true`/`#false`)
- ✅ Null (`null` and `#null`)
- ✅ Special numbers (`#inf`, `#-inf`, `#nan`)

### Structure
- ✅ Nodes with arguments and properties
- ✅ Children blocks
- ✅ Type annotations
- ✅ Comments (single-line, multi-line, slashdash)
- ✅ Line continuations
- ✅ Unicode identifiers

### Serialization
- ✅ Swift Codable support
- ✅ Custom encoding/decoding strategies
- ✅ Array and dictionary support
- ✅ Optional value handling

## Documentation

This package includes comprehensive DocC documentation with guides, examples, and API reference.

### Online Documentation

View the latest stable release documentation at: https://your-username.github.io/kdl-swift/

*Note: Documentation is updated with each release to ensure it reflects the stable API.*

### Generating Documentation Locally

To generate and view the documentation locally:

```bash
# Generate documentation
xcodebuild docbuild -scheme KDL -destination 'generic/platform=macOS' -derivedDataPath .build

# Open documentation
open .build/Build/Products/Debug/KDL.doccarchive
```

The documentation includes:
- Getting started guide with examples
- Codable integration tutorial
- Complete API reference
- Version differences and best practices

## Requirements

- Swift 6.1+
- macOS 13.0+, iOS 16.0+, tvOS 16.0+, watchOS 9.0+

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.