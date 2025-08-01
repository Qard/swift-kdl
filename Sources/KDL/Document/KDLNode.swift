//
//  KDLNode.swift
//  node.builders
//
//  KDL node representation with arguments, properties, and children
//

import Foundation

/// Represents a node in a KDL document
///
/// A node is the fundamental building block of a KDL document. Each node has:
/// - A name (identifier)
/// - Optional type annotation
/// - Zero or more arguments (positional values)
/// - Zero or more properties (key-value pairs)
/// - Zero or more child nodes
///
/// Example:
/// ```kdl
/// package "my-app" version="1.0.0" {
///     dependency "kdl" "^2.0"
/// }
/// ```
public struct KDLNode: Equatable {
    /// The node identifier/name
    public let name: String

    /// Type annotation for the node (optional)
    /// Example: `(person)author "John Doe"`
    public let typeAnnotation: KDLTypeAnnotation?

    /// Positional arguments for the node
    public let arguments: [KDLValue]

    /// Named properties for the node
    public var properties: [String: KDLValue]

    /// Child nodes
    public let children: [KDLNode]

    /// Source location information for error reporting
    public let location: KDLSourceLocation?

    public init(
        name: String,
        typeAnnotation: KDLTypeAnnotation? = nil,
        arguments: [KDLValue] = [],
        properties: [String: KDLValue] = [:],
        children: [KDLNode] = [],
        location: KDLSourceLocation? = nil
    ) {
        self.name = name
        self.typeAnnotation = typeAnnotation
        self.arguments = arguments
        self.properties = properties
        self.children = children
        self.location = location
    }

    /// Get a property value by key
    /// - Parameter key: The property key to look up
    /// - Returns: The value if the property exists, nil otherwise
    public func property(_ key: String) -> KDLValue? {
        return properties[key]
    }

    /// Get the first argument value
    /// - Returns: The first argument if any exist, nil otherwise
    public var firstArgument: KDLValue? {
        return arguments.first
    }

    /// Find child nodes by name
    /// - Parameter name: The name to search for
    /// - Returns: An array of child nodes with the given name
    public func children(named name: String) -> [KDLNode] {
        return children.filter { $0.name == name }
    }

    /// Find the first child node by name
    /// - Parameter name: The name to search for
    /// - Returns: The first child node with the given name, or nil if not found
    public func child(named name: String) -> KDLNode? {
        return children.first { $0.name == name }
    }
}
