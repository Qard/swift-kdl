//
//  KDL.swift
//  KDL
//
//  Main module export file
//

/// A Swift implementation of the KDL Document Language
///
/// KDL (pronounced "cuddle") is a document language with a clean syntax and rich semantics.
/// It's designed to be easy to read and write, with a minimal set of concepts.
///
/// ## Basic Usage
///
/// ### Parsing KDL
/// ```swift
/// let kdl = """
/// title "Hello, World!"
/// author "Jane Doe" email="jane@example.com"
/// """
///
/// let document = try KDLParser.parse(kdl)
/// print(document.nodes[0].arguments[0]) // .string("Hello, World!")
/// ```
///
/// ### Using Codable
/// ```swift
/// struct Config: Codable {
///     let title: String
///     let author: String
/// }
///
/// let decoder = KDLDecoder()
/// let config = try decoder.decode(Config.self, from: kdl)
/// ```
///
/// ### Creating KDL
/// ```swift
/// let document = KDLDocument(nodes: [
///     KDLNode(name: "title", arguments: [.string("My App")]),
///     KDLNode(name: "version", arguments: [.string("1.0.0")])
/// ])
///
/// let formatter = KDLFormatter()
/// let kdl = formatter.format(document)
/// ```

// Re-export all public types
public typealias KDL = KDLDocument

/// KDL specification version.
///
/// The KDL specification has evolved over time, with different versions having slightly different syntax:
///
/// - **KDL 1.x**: Uses `true`, `false`, and `null` as reserved keywords
/// - **KDL 2.x**: Uses `#true`, `#false`, and `#null`, treating unquoted keywords as identifiers
///
/// The parser and encoder can automatically detect the version or work with a specific version.
///
/// ## Version Detection
///
/// When using `.auto`, the version is detected based on the content:
/// - If `#true`, `#false`, or `#null` are found, it's detected as KDL 2.x
/// - If `true`, `false`, or `null` are found, it's detected as KDL 1.x
/// - A version marker like `/- kdl-version 2` can explicitly specify the version
///
/// ## Usage
///
/// ```swift
/// // Auto-detect version
/// let parser = KDLParser(input: kdl, version: .auto)
///
/// // Force specific version
/// let parser = KDLParser(input: kdl, version: .v2)
/// ```
public enum KDLVersion {
    /// KDL 1.x - uses `true`, `false`, `null` as reserved keywords
    case v1
    /// KDL 2.x - uses `#true`, `#false`, `#null` and treats unquoted keywords as identifiers
    case v2
    /// Auto-detect version based on content
    case auto
}