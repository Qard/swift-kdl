# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Swift package that implements a KDL (Cuddly Data Language) parser and writer. KDL is a document language similar to XML/JSON but with a cleaner syntax.

## Build and Development Commands

### Building
```bash
# Build debug version
swift build

# Build release version
swift build -c release

# Clean build artifacts
swift package clean
```

### Testing
```bash
# Run all tests
swift test

# Run tests with verbose output
swift test --verbose
```

### Package Management
```bash
# Update dependencies
swift package update

# Resolve dependencies
swift package resolve

# Generate Xcode project (if needed)
swift package generate-xcodeproj
```

## Architecture Overview

The KDL parser follows a standard compiler architecture organized into distinct modules:

### Parsing Module (`Sources/KDL/Parsing/`)
1. **Lexical Analysis** (`KDLLexer.swift`)
   - Tokenizes input into KDL tokens
   - Handles trivia (whitespace/comments)
   - Tracks source locations for error reporting

2. **Token Definitions** (`KDLToken.swift`)
   - Token representation with type and location information
   - Defines all KDL token types

3. **Parsing** (`KDLParser.swift`)
   - Recursive descent parser
   - Builds abstract syntax tree from tokens
   - Produces `KDLDocument` containing `KDLNode` structures

### Encoding Module (`Sources/KDL/Encoding/`)
1. **Codable Encoder** (`KDLEncoder.swift`)
   - Swift Codable protocol support for encoding to KDL
   - Configurable encoding strategies

2. **Formatting** (`KDLFormatter.swift`)
   - Converts KDL AST back to formatted text
   - Preserves or reformats based on configuration

### Decoding Module (`Sources/KDL/Decoding/`)
1. **Codable Decoder** (`KDLDecoder.swift`)
   - Swift Codable protocol support for decoding from KDL
   - Configurable decoding strategies

### Core Data Structures (Root Level)
- `KDL.swift`: Main module entry point and version information
- `KDLNode.swift`: Represents nodes with name, arguments, properties, and children
- `KDLValue.swift`: Enum for KDL value types (string, integer, decimal, boolean, null)
- `KDLError.swift`: Error types for parsing and validation

## Key Implementation Details

- The parser uses a lookahead mechanism with `currentToken` and `peekedToken`
- Source locations are tracked throughout for error reporting
- The lexer handles KDL-specific features like type annotations and escaped strings
- Configuration parsers build on the base parser for domain-specific structures

## Testing Approach

Tests use Swift Testing framework (not XCTest). Use `@Test` attribute and `#expect()` for assertions. Test files should be in `Tests/KDLTests/` directory.

## Target Configuration

The package targets are configured in `Package.swift`:
- Library target: `KDL`
- Test target: `KDLTests`
- Minimum Swift version: 6.1
