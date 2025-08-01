//
//  KDLDocument.swift
//  node.builders
//
//  Represents a complete KDL document
//

import Foundation

/// Represents a complete KDL document
///
/// A KDL document is a collection of nodes at the root level.
/// Documents can be parsed from strings or constructed programmatically.
///
/// Example:
/// ```swift
/// let document = KDLDocument(nodes: [
///     KDLNode(name: "title", arguments: [.string("My Document")]),
///     KDLNode(name: "author", arguments: [.string("Jane Doe")])
/// ])
/// ```
public struct KDLDocument: Equatable {
    /// The root-level nodes in the document
    public let nodes: [KDLNode]

    /// Initialize a new KDL document
    /// - Parameter nodes: The root-level nodes
    public init(nodes: [KDLNode]) {
        self.nodes = nodes
    }

    /// Find nodes by name at the document root
    /// - Parameter name: The name to search for
    /// - Returns: An array of nodes with the given name
    public func nodes(named name: String) -> [KDLNode] {
        return nodes.filter { $0.name == name }
    }

    /// Find the first node by name at the document root
    /// - Parameter name: The name to search for
    /// - Returns: The first node with the given name, or nil if not found
    public func node(named name: String) -> KDLNode? {
        return nodes.first { $0.name == name }
    }
}
