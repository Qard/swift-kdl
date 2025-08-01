//
//  KDLParser.swift
//  KDL
//
//  Parser for KDL documents with full KDL 2.0 support
//

import Foundation

/// Parser for KDL documents with full KDL 1.x and 2.x support.
///
/// `KDLParser` converts KDL text into a structured ``KDLDocument`` containing ``KDLNode`` objects.
/// The parser supports automatic version detection or can be configured for a specific KDL version.
///
/// ## Usage
///
/// ```swift
/// let kdl = """
/// name "my-app"
/// server {
///     host "localhost"
///     port 8080
/// }
/// """
///
/// let parser = KDLParser(input: kdl)
/// let document = try parser.parseDocument()
/// ```
///
/// ## Version Support
///
/// The parser automatically detects KDL version based on the content:
/// - KDL 1.x: Uses `true`, `false`, `null` as keywords
/// - KDL 2.x: Uses `#true`, `#false`, `#null` and treats unquoted keywords as identifiers
///
/// You can also specify a version explicitly:
///
/// ```swift
/// let parser = KDLParser(input: kdl, version: .v2)
/// ```
public class KDLParser {
    private let lexer: KDLLexer
    private var currentToken: KDLToken?
    private var peekedToken: KDLToken?
    
    /// Create a parser with automatic version detection.
    /// - Parameter input: The KDL text to parse
    public init(input: String) {
        self.lexer = KDLLexer(input: input)
    }
    
    /// Create a parser with a specific KDL version.
    /// - Parameters:
    ///   - input: The KDL text to parse
    ///   - version: The KDL version to use for parsing
    public init(input: String, version: KDLVersion) {
        self.lexer = KDLLexer(input: input, version: version)
    }
    
    /// Parse the input text into a KDL document.
    /// - Returns: A ``KDLDocument`` containing the parsed nodes
    /// - Throws: ``KDLError`` if the input contains syntax errors
    public func parseDocument() throws -> KDLDocument {
        var nodes: [KDLNode] = []
        
        // Initialize with first token
        _ = try advance()
        
        while !isAtEnd() {
            // Skip newlines at document level
            if current?.type == .newline {
                _ = try advance()
                continue
            }
            
            // Handle slashdash at document level
            if current?.type == .slashdash {
                _ = try advance()
                // Skip the next node
                _ = try skipNode()
                continue
            }
            
            let node = try parseNode()
            nodes.append(node)
        }
        
        return KDLDocument(nodes: nodes)
    }
    
    /// Get the detected or specified KDL version
    public var version: KDLVersion {
        return lexer.version
    }
    
    // MARK: - Node Parsing
    
    private func parseNode() throws -> KDLNode {
        // Skip newlines
        while current?.type == .newline {
            _ = try advance()
        }
        
        guard let token = current else {
            throw KDLError.unexpectedEndOfFile
        }
        
        // Parse type annotation if present (comes before node name)
        var typeAnnotation: KDLTypeAnnotation?
        var name: String
        var nodeLocation: KDLSourceLocation
        
        if case .typeAnnotation(let typeName) = token.type {
            typeAnnotation = KDLTypeAnnotation(name: typeName)
            _ = try advance()
            
            guard let nameToken = current else {
                throw KDLError.unexpectedEndOfFile
            }
            
            // Parse node name after type annotation
            guard case .identifier(let nodeName) = nameToken.type else {
                throw KDLError.unexpectedToken(String(describing: nameToken.type), location: nameToken.location)
            }
            
            name = nodeName
            nodeLocation = nameToken.location
            _ = try advance()
        } else {
            // Parse node name without type annotation
            guard case .identifier(let nodeName) = token.type else {
                throw KDLError.unexpectedToken(String(describing: token.type), location: token.location)
            }
            
            name = nodeName
            nodeLocation = token.location
            _ = try advance()
        }
        
        // Parse arguments and properties
        var arguments: [KDLValue] = []
        var properties: [String: KDLValue] = [:]
        
        while let token = current, !isNodeTerminator(token) {
            // Handle slashdash for arguments/properties
            if token.type == .slashdash {
                _ = try advance()
                // Skip the next value or property
                if let nextToken = current {
                    if case .identifier = nextToken.type, peek()?.type == .equals {
                        // Skip property
                        _ = try advance() // identifier
                        _ = try advance() // equals
                        _ = try advance() // value
                    } else if nextToken.value != nil {
                        // Skip argument
                        _ = try advance()
                    }
                }
                continue
            }
            
            if case .identifier(let key) = token.type, peek()?.type == .equals {
                // This is a property
                _ = try advance() // Skip identifier
                _ = try advance() // Skip equals
                
                guard let valueToken = current, let value = valueToken.value else {
                    throw KDLError.unexpectedToken("Expected value after '='", location: token.location)
                }
                
                if properties[key] != nil {
                    throw KDLError.duplicateProperty(key, location: token.location)
                }
                
                properties[key] = value
                _ = try advance()
            } else if let value = token.value {
                // This is an argument
                arguments.append(value)
                _ = try advance()
            } else if token.type == .leftBrace {
                // This starts a children block - break and handle below
                break
            } else {
                throw KDLError.unexpectedToken(String(describing: token.type), location: token.location)
            }
        }
        
        // Parse children if present
        var children: [KDLNode] = []
        if current?.type == .leftBrace {
            _ = try advance() // Skip {
            
            while current?.type != .rightBrace && !isAtEnd() {
                // Skip newlines in children block
                if current?.type == .newline {
                    _ = try advance()
                    continue
                }
                
                // Handle slashdash in children
                if current?.type == .slashdash {
                    _ = try advance()
                    _ = try skipNode()
                    continue
                }
                
                let child = try parseNode()
                children.append(child)
            }
            
            guard current?.type == .rightBrace else {
                throw KDLError.unexpectedToken("Expected '}'", location: current?.location ?? nodeLocation)
            }
            _ = try advance() // Skip }
        }
        
        // Skip optional semicolon or newline
        if current?.type == .semicolon || current?.type == .newline {
            _ = try advance()
        }
        
        return KDLNode(
            name: name,
            typeAnnotation: typeAnnotation,
            arguments: arguments,
            properties: properties,
            children: children,
            location: nodeLocation
        )
    }
    
    /// Skip a node (used for slashdash comments)
    private func skipNode() throws {
        // Skip node name
        guard case .identifier = current?.type else {
            return
        }
        _ = try advance()
        
        // Skip type annotation if present
        if case .typeAnnotation = current?.type {
            _ = try advance()
        }
        
        // Skip arguments and properties
        while let token = current, !isNodeTerminator(token) {
            if token.type == .leftBrace {
                break
            }
            _ = try advance()
        }
        
        // Skip children if present
        if current?.type == .leftBrace {
            _ = try advance() // Skip {
            var braceDepth = 1
            
            while braceDepth > 0 && !isAtEnd() {
                if current?.type == .leftBrace {
                    braceDepth += 1
                } else if current?.type == .rightBrace {
                    braceDepth -= 1
                }
                _ = try advance()
            }
        }
        
        // Skip terminator
        if current?.type == .semicolon || current?.type == .newline {
            _ = try advance()
        }
    }
    
    // MARK: - Helper Methods
    
    private func isNodeTerminator(_ token: KDLToken) -> Bool {
        switch token.type {
        case .semicolon, .newline, .eof, .rightBrace:
            return true
        case .leftBrace:
            return false // Left brace starts children, doesn't terminate arguments
        default:
            return false
        }
    }
    
    private func advance() throws -> KDLToken? {
        if let peeked = peekedToken {
            currentToken = peeked
            peekedToken = nil
        } else {
            currentToken = try lexer.nextToken()
        }
        return currentToken
    }
    
    private func peek() -> KDLToken? {
        if peekedToken == nil {
            peekedToken = try? lexer.nextToken()
        }
        return peekedToken
    }
    
    private var current: KDLToken? {
        return currentToken
    }
    
    private func isAtEnd() -> Bool {
        return current?.type == .eof
    }
}

// MARK: - Public API Extensions

public extension KDLParser {
    /// Parse a KDL document from a string (auto-detects version)
    static func parse(_ input: String) throws -> KDLDocument {
        let parser = KDLParser(input: input)
        return try parser.parseDocument()
    }
    
    /// Parse a KDL document from a string with a specific version
    static func parse(_ input: String, version: KDLVersion) throws -> KDLDocument {
        let parser = KDLParser(input: input, version: version)
        return try parser.parseDocument()
    }
    
    /// Parse a KDL document from a file URL (auto-detects version)
    static func parse(contentsOf url: URL) throws -> KDLDocument {
        let input = try String(contentsOf: url, encoding: .utf8)
        return try parse(input)
    }
    
    /// Parse a KDL document from a file URL with a specific version
    static func parse(contentsOf url: URL, version: KDLVersion) throws -> KDLDocument {
        let input = try String(contentsOf: url, encoding: .utf8)
        return try parse(input, version: version)
    }
    
    /// Parse a KDL document preserving formatting information
    static func parsePreservingFormat(_ input: String) throws -> KDLDocument {
        // TODO: Implement format-preserving parser
        // For now, just parse normally
        return try parse(input)
    }
}