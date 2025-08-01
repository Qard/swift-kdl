//
//  KDLDecoder.swift
//  KDL
//
//  Decoder for converting KDL documents to Swift types
//

import Foundation

/// A decoder that converts KDL documents to Swift types conforming to `Decodable`.
///
/// `KDLDecoder` provides seamless integration with Swift's `Codable` system, allowing you to
/// decode KDL documents directly into Swift structs, classes, and enums.
///
/// ## Basic Usage
///
/// ```swift
/// struct ServerConfig: Codable {
///     let host: String
///     let port: Int
///     let secure: Bool
/// }
///
/// let kdl = """
/// host "localhost"
/// port 8080
/// secure true
/// """
///
/// let decoder = KDLDecoder()
/// let config = try decoder.decode(ServerConfig.self, from: kdl)
/// ```
///
/// ## Configuration Options
///
/// The decoder provides several strategies for handling different aspects of decoding:
///
/// - ``keyDecodingStrategy``: How to convert KDL node names to Swift property names
/// - ``dateDecodingStrategy``: How to decode date values
/// - ``nonConformingFloatDecodingStrategy``: How to handle special float values like infinity and NaN
/// - ``preservesFormat``: Whether to capture formatting information for later encoding
///
/// ## Format Preservation
///
/// When `preservesFormat` is enabled, the decoder captures formatting information that can be used
/// to preserve the original document's style when encoding:
///
/// ```swift
/// let decoder = KDLDecoder()
/// decoder.preservesFormat = true
///
/// let config = try decoder.decode(MyConfig.self, from: originalKDL)
/// let encoder = decoder.createEncoder() // Preserves original formatting
/// ```
public class KDLDecoder {
    /// The format context from the most recent decode operation
    public private(set) var capturedFormatContext: KDLFormatContext?

    /// Enable format preservation during decoding
    public var preservesFormat: Bool = false

    /// User-provided information to be made available during decoding
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    /// The strategy to use for decoding keys
    public var keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys

    /// The strategy to use for decoding dates
    public var dateDecodingStrategy: DateDecodingStrategy = .iso8601

    /// The strategy to use for non-conforming floating-point values
    public var nonConformingFloatDecodingStrategy: NonConformingFloatDecodingStrategy =
        .convertFromString(
            positiveInfinity: "#inf",
            negativeInfinity: "#-inf",
            nan: "#nan"
        )

    /// KDL version to parse as (default: auto-detect)
    public var version: KDLVersion = .auto

    public init() {}

    /// Decodes a value of the given type from KDL data
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard let string = String(data: data, encoding: .utf8) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: [],
                    debugDescription: "The given data could not be decoded as UTF-8"
                ))
        }
        return try decode(type, from: string)
    }

    /// Decodes a value of the given type from a KDL string
    public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        let document: KDLDocument

        if preservesFormat {
            document = try KDLParser.parsePreservingFormat(string)
            capturedFormatContext = KDLFormatContext(originalDocument: document)
        } else {
            document = try KDLParser.parse(string, version: version)
            capturedFormatContext = nil
        }

        let decoder = _KDLDecoder(
            document: document,
            keyDecodingStrategy: keyDecodingStrategy,
            dateDecodingStrategy: dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: nonConformingFloatDecodingStrategy,
            userInfo: userInfo
        )

        return try T(from: decoder)
    }

    /// Creates a paired encoder with format context
    public func createEncoder() -> KDLEncoder {
        if let context = capturedFormatContext {
            return KDLEncoder(formatContext: context)
        } else {
            return KDLEncoder()
        }
    }
}

// MARK: - Decoding Strategies

extension KDLDecoder {
    /// The strategy to use for decoding keys
    public enum KeyDecodingStrategy {
        case useDefaultKeys
        case convertFromKebabCase
        case custom((String) -> String)
    }

    /// The strategy to use for decoding dates
    public enum DateDecodingStrategy {
        case deferredToDate
        case iso8601
        case secondsSince1970
        case millisecondsSince1970
        case custom((Decoder) throws -> Date)
    }

    /// The strategy to use for non-conforming floating-point values
    public enum NonConformingFloatDecodingStrategy {
        case `throw`
        case convertFromString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }
}

// MARK: - Format Context

// MARK: - Internal Decoder Implementation

private class _KDLDecoder: Decoder {
    let document: KDLDocument
    let keyDecodingStrategy: KDLDecoder.KeyDecodingStrategy
    let dateDecodingStrategy: KDLDecoder.DateDecodingStrategy
    let nonConformingFloatDecodingStrategy: KDLDecoder.NonConformingFloatDecodingStrategy

    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]

    init(
        document: KDLDocument,
        keyDecodingStrategy: KDLDecoder.KeyDecodingStrategy,
        dateDecodingStrategy: KDLDecoder.DateDecodingStrategy,
        nonConformingFloatDecodingStrategy: KDLDecoder.NonConformingFloatDecodingStrategy,
        userInfo: [CodingUserInfoKey: Any],
        codingPath: [CodingKey] = []
    ) {
        self.document = document
        self.keyDecodingStrategy = keyDecodingStrategy
        self.dateDecodingStrategy = dateDecodingStrategy
        self.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
        self.userInfo = userInfo
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
    where Key: CodingKey {
        let container = KDLKeyedDecodingContainer<Key>(
            document: document,
            decoder: self,
            codingPath: codingPath
        )
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return KDLUnkeyedDecodingContainer(
            nodes: document.nodes,
            decoder: self,
            codingPath: codingPath
        )
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return KDLSingleValueDecodingContainer(
            document: document,
            decoder: self,
            codingPath: codingPath
        )
    }
}

// MARK: - Keyed Container

private struct KDLKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K

    let document: KDLDocument
    let decoder: _KDLDecoder
    var codingPath: [CodingKey]

    var allKeys: [K] {
        // Get all unique node names and properties
        var keys = Set<String>()

        for node in document.nodes {
            keys.insert(node.name)
            for key in node.properties.keys {
                keys.insert(key)
            }
        }

        return keys.compactMap { K(stringValue: $0) }
    }

    func contains(_ key: K) -> Bool {
        let keyString = decoder.convertKey(key.stringValue)

        // Check if there's a node with this name
        if document.node(named: keyString) != nil {
            return true
        }

        // Check if any node has this property
        for node in document.nodes {
            if node.property(keyString) != nil {
                return true
            }
        }

        return false
    }

    func decodeNil(forKey key: K) throws -> Bool {
        let keyString = decoder.convertKey(key.stringValue)

        // Check nodes first
        if let node = document.node(named: keyString) {
            return node.arguments.isEmpty && node.properties.isEmpty && node.children.isEmpty
        }

        // Check properties
        for node in document.nodes {
            if let value = node.property(keyString) {
                return value == .null
            }
        }

        return true  // Key not found means nil
    }

    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T: Decodable {
        let keyString = decoder.convertKey(key.stringValue)

        // Special handling for primitive types from properties
        if let value = findPropertyValue(forKey: keyString) {
            return try decodePrimitive(type, from: value, forKey: key)
        }

        // Handle nodes
        if let node = document.node(named: keyString) {
            return try decodeFromNode(type, node: node, forKey: key)
        }

        throw DecodingError.keyNotFound(
            key,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "No value associated with key \(key.stringValue)"
            ))
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws
    -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        let keyString = decoder.convertKey(key.stringValue)

        guard let node = document.node(named: keyString) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription:
                        "Cannot get nested keyed container -- no value found for key \(key.stringValue)"
                ))
        }

        let childDocument = KDLDocument(nodes: node.children)
        let childDecoder = _KDLDecoder(
            document: childDocument,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo,
            codingPath: codingPath + [key]
        )

        return try childDecoder.container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        let keyString = decoder.convertKey(key.stringValue)

        guard let node = document.node(named: keyString) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription:
                        "Cannot get nested unkeyed container -- no value found for key \(key.stringValue)"
                ))
        }

        return KDLUnkeyedDecodingContainer(
            nodes: node.children,
            decoder: decoder,
            codingPath: codingPath + [key]
        )
    }

    func superDecoder() throws -> Decoder {
        return decoder
    }

    func superDecoder(forKey key: K) throws -> Decoder {
        let keyString = decoder.convertKey(key.stringValue)

        guard let node = document.node(named: keyString) else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get super decoder -- no value found for key \(key.stringValue)"
                ))
        }

        let childDocument = KDLDocument(nodes: [node])
        return _KDLDecoder(
            document: childDocument,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo,
            codingPath: codingPath + [key]
        )
    }

    // MARK: - Helper Methods

    private func findPropertyValue(forKey key: String) -> KDLValue? {
        for node in document.nodes {
            if let value = node.property(key) {
                return value
            }
        }
        return nil
    }

    private func decodePrimitive<T>(_ type: T.Type, from value: KDLValue, forKey key: K) throws -> T
    where T: Decodable {
        let primitiveDecoder = KDLPrimitiveDecoder(
            value: value,
            decoder: decoder,
            codingPath: codingPath + [key]
        )
        return try T(from: primitiveDecoder)
    }

    private func decodeFromNode<T>(_ type: T.Type, node: KDLNode, forKey key: K) throws -> T
    where T: Decodable {
        // If the node has a single argument and no properties/children, decode that argument directly
        if node.arguments.count == 1 && node.properties.isEmpty && node.children.isEmpty {
            return try decodePrimitive(type, from: node.arguments[0], forKey: key)
        }

        // If the node has multiple arguments, decode as array
        if node.arguments.count > 1 && node.properties.isEmpty && node.children.isEmpty {
            let arrayDecoder = KDLArrayDecoder(
                values: node.arguments,
                decoder: decoder,
                codingPath: codingPath + [key]
            )
            return try T(from: arrayDecoder)
        }

        // If the node has only properties (no arguments or children), decode as dictionary
        if node.arguments.isEmpty && !node.properties.isEmpty && node.children.isEmpty {
            let dictionaryDecoder = KDLDictionaryDecoder(
                properties: node.properties,
                decoder: decoder,
                codingPath: codingPath + [key]
            )
            return try T(from: dictionaryDecoder)
        }

        // Otherwise decode as nested object
        let childDocument = KDLDocument(nodes: node.children.isEmpty ? [node] : node.children)
        let childDecoder = _KDLDecoder(
            document: childDocument,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo,
            codingPath: codingPath + [key]
        )

        return try T(from: childDecoder)
    }
}

// MARK: - Unkeyed Container

private struct KDLUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    let nodes: [KDLNode]
    let decoder: _KDLDecoder
    var codingPath: [CodingKey]

    private(set) var currentIndex: Int = 0

    var count: Int? { nodes.count }
    var isAtEnd: Bool { currentIndex >= nodes.count }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Unkeyed container is at end"
                ))
        }

        let node = nodes[currentIndex]
        if node.arguments.isEmpty && node.properties.isEmpty && node.children.isEmpty {
            currentIndex += 1
            return true
        }

        return false
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Unkeyed container is at end"
                ))
        }

        let node = nodes[currentIndex]
        currentIndex += 1

        let childDocument = KDLDocument(nodes: [node])
        let childDecoder = _KDLDecoder(
            document: childDocument,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo,
            codingPath: codingPath + [IndexKey(intValue: currentIndex - 1)]
        )

        return try T(from: childDecoder)
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws
    -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                KeyedDecodingContainer<NestedKey>.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get nested keyed container -- unkeyed container is at end"
                ))
        }

        let node = nodes[currentIndex]
        currentIndex += 1

        let childDocument = KDLDocument(nodes: node.children)
        let childDecoder = _KDLDecoder(
            document: childDocument,
            keyDecodingStrategy: decoder.keyDecodingStrategy,
            dateDecodingStrategy: decoder.dateDecodingStrategy,
            nonConformingFloatDecodingStrategy: decoder.nonConformingFloatDecodingStrategy,
            userInfo: decoder.userInfo,
            codingPath: codingPath + [IndexKey(intValue: currentIndex - 1)]
        )

        return try childDecoder.container(keyedBy: type)
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                UnkeyedDecodingContainer.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Cannot get nested unkeyed container -- unkeyed container is at end"
                ))
        }

        let node = nodes[currentIndex]
        currentIndex += 1

        return KDLUnkeyedDecodingContainer(
            nodes: node.children,
            decoder: decoder,
            codingPath: codingPath + [IndexKey(intValue: currentIndex - 1)]
        )
    }

    mutating func superDecoder() throws -> Decoder {
        return decoder
    }
}

// MARK: - Single Value Container

private struct KDLSingleValueDecodingContainer: SingleValueDecodingContainer {
    let document: KDLDocument
    let decoder: _KDLDecoder
    var codingPath: [CodingKey]

    func decodeNil() -> Bool {
        return document.nodes.isEmpty
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        // If document has a single node with a single argument, decode that
        if document.nodes.count == 1,
           let node = document.nodes.first,
           node.arguments.count == 1,
           node.properties.isEmpty,
           node.children.isEmpty,
           let value = node.arguments.first {

            let primitiveDecoder = KDLPrimitiveDecoder(
                value: value,
                decoder: decoder,
                codingPath: codingPath
            )
            return try T(from: primitiveDecoder)
        }

        // Otherwise, decode the entire document
        return try T(from: decoder)
    }
}

// MARK: - Primitive Decoder

private class KDLPrimitiveDecoder: Decoder {
    let value: KDLValue
    let decoder: _KDLDecoder
    var codingPath: [CodingKey]

    var userInfo: [CodingUserInfoKey: Any] { decoder.userInfo }

    init(value: KDLValue, decoder: _KDLDecoder, codingPath: [CodingKey]) {
        self.value = value
        self.decoder = decoder
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
    where Key: CodingKey {
        throw DecodingError.typeMismatch(
            KeyedDecodingContainer<Key>.self,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Cannot decode keyed container from primitive value"
            ))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            UnkeyedDecodingContainer.self,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Cannot decode unkeyed container from primitive value"
            ))
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return KDLPrimitiveSingleValueContainer(value: value, codingPath: codingPath)
    }
}

// MARK: - Primitive Single Value Container

private struct KDLPrimitiveSingleValueContainer: SingleValueDecodingContainer {
    let value: KDLValue
    var codingPath: [CodingKey]

    func decodeNil() -> Bool {
        return value == .null
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        guard case .boolean(let bool) = value else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected Bool but found \(value)"
                ))
        }
        return bool
    }

    func decode(_ type: String.Type) throws -> String {
        guard case .string(let string) = value else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected String but found \(value)"
                ))
        }
        return string
    }

    func decode(_ type: Double.Type) throws -> Double {
        switch value {
        case .decimal(let double):
            return double
        case .integer(let int):
            return Double(int)
        default:
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected Double but found \(value)"
                ))
        }
    }

    func decode(_ type: Float.Type) throws -> Float {
        switch value {
        case .decimal(let double):
            return Float(double)
        case .integer(let int):
            return Float(int)
        default:
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected Float but found \(value)"
                ))
        }
    }

    func decode(_ type: Int.Type) throws -> Int {
        guard case .integer(let int) = value else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected Int but found \(value)"
                ))
        }
        guard int >= Int.min && int <= Int.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Integer value \(int) out of range for Int"
                ))
        }
        return Int(int)
    }

    func decode(_ type: Int8.Type) throws -> Int8 {
        guard case .integer(let int) = value else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected Int8 but found \(value)"
                ))
        }
        guard int >= Int8.min && int <= Int8.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Integer value \(int) out of range for Int8"
                ))
        }
        return Int8(int)
    }

    func decode(_ type: Int16.Type) throws -> Int16 {
        guard case .integer(let int) = value else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected Int16 but found \(value)"
                ))
        }
        guard int >= Int16.min && int <= Int16.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Integer value \(int) out of range for Int16"
                ))
        }
        return Int16(int)
    }

    func decode(_ type: Int32.Type) throws -> Int32 {
        guard case .integer(let int) = value else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected Int32 but found \(value)"
                ))
        }
        guard int >= Int32.min && int <= Int32.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Integer value \(int) out of range for Int32"
                ))
        }
        return Int32(int)
    }

    func decode(_ type: Int64.Type) throws -> Int64 {
        guard case .integer(let int) = value else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected Int64 but found \(value)"
                ))
        }
        return int
    }

    func decode(_ type: UInt.Type) throws -> UInt {
        guard case .integer(let int) = value else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected UInt but found \(value)"
                ))
        }
        guard int >= 0 && int <= UInt.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Integer value \(int) out of range for UInt"
                ))
        }
        return UInt(int)
    }

    func decode(_ type: UInt8.Type) throws -> UInt8 {
        guard case .integer(let int) = value else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected UInt8 but found \(value)"
                ))
        }
        guard int >= 0 && int <= UInt8.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Integer value \(int) out of range for UInt8"
                ))
        }
        return UInt8(int)
    }

    func decode(_ type: UInt16.Type) throws -> UInt16 {
        guard case .integer(let int) = value else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected UInt16 but found \(value)"
                ))
        }
        guard int >= 0 && int <= UInt16.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Integer value \(int) out of range for UInt16"
                ))
        }
        return UInt16(int)
    }

    func decode(_ type: UInt32.Type) throws -> UInt32 {
        guard case .integer(let int) = value else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected UInt32 but found \(value)"
                ))
        }
        guard int >= 0 && int <= UInt32.max else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Integer value \(int) out of range for UInt32"
                ))
        }
        return UInt32(int)
    }

    func decode(_ type: UInt64.Type) throws -> UInt64 {
        guard case .integer(let int) = value else {
            throw DecodingError.typeMismatch(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Expected UInt64 but found \(value)"
                ))
        }
        guard int >= 0 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Integer value \(int) out of range for UInt64"
                ))
        }
        return UInt64(int)
    }

    func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        // Create a dummy decoder for primitive values
        let dummyDocument = KDLDocument(nodes: [])
        let dummyDecoder = _KDLDecoder(
            document: dummyDocument,
            keyDecodingStrategy: .useDefaultKeys,
            dateDecodingStrategy: .iso8601,
            nonConformingFloatDecodingStrategy: .throw,
            userInfo: [:]
        )
        return try T(
            from: KDLPrimitiveDecoder(value: value, decoder: dummyDecoder, codingPath: codingPath))
    }
}

// MARK: - Array Decoder

private class KDLArrayDecoder: Decoder {
    let values: [KDLValue]
    let decoder: _KDLDecoder
    var codingPath: [CodingKey]

    var userInfo: [CodingUserInfoKey: Any] { decoder.userInfo }

    init(values: [KDLValue], decoder: _KDLDecoder, codingPath: [CodingKey]) {
        self.values = values
        self.decoder = decoder
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
    where Key: CodingKey {
        throw DecodingError.typeMismatch(
            KeyedDecodingContainer<Key>.self,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Cannot decode keyed container from array"
            ))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        return KDLArrayUnkeyedContainer(values: values, decoder: decoder, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw DecodingError.typeMismatch(
            SingleValueDecodingContainer.self,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Cannot decode single value from array"
            ))
    }
}

// MARK: - Array Unkeyed Container

private struct KDLArrayUnkeyedContainer: UnkeyedDecodingContainer {
    let values: [KDLValue]
    let decoder: _KDLDecoder
    var codingPath: [CodingKey]

    private(set) var currentIndex: Int = 0

    var count: Int? { values.count }
    var isAtEnd: Bool { currentIndex >= values.count }

    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                Any?.self,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Unkeyed container is at end"
                ))
        }

        if values[currentIndex] == .null {
            currentIndex += 1
            return true
        }

        return false
    }

    mutating func decode<T>(_ type: T.Type) throws -> T where T: Decodable {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(
                type,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "Unkeyed container is at end"
                ))
        }

        let value = values[currentIndex]
        currentIndex += 1

        let primitiveDecoder = KDLPrimitiveDecoder(
            value: value,
            decoder: decoder,
            codingPath: codingPath + [IndexKey(intValue: currentIndex - 1)]
        )

        return try T(from: primitiveDecoder)
    }

    mutating func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type) throws
    -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        throw DecodingError.typeMismatch(
            KeyedDecodingContainer<NestedKey>.self,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Cannot decode nested keyed container from primitive value"
            ))
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            UnkeyedDecodingContainer.self,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Cannot decode nested unkeyed container from primitive value"
            ))
    }

    mutating func superDecoder() throws -> Decoder {
        return decoder
    }
}

// MARK: - Helper Types

private struct IndexKey: CodingKey {
    let intValue: Int?
    let stringValue: String

    init(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }

    init?(stringValue: String) {
        self.intValue = Int(stringValue)
        self.stringValue = stringValue
    }
}

// MARK: - Key Conversion

extension _KDLDecoder {
    fileprivate func convertKey(_ key: String) -> String {
        switch keyDecodingStrategy {
        case .useDefaultKeys:
            return key
        case .convertFromKebabCase:
            return key.replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
                .lowercased()
        case .custom(let converter):
            return converter(key)
        }
    }
}

// MARK: - Dictionary Decoder

private class KDLDictionaryDecoder: Decoder {
    let properties: [String: KDLValue]
    let parentDecoder: _KDLDecoder

    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { return parentDecoder.userInfo }

    init(properties: [String: KDLValue], decoder: _KDLDecoder, codingPath: [CodingKey]) {
        self.properties = properties
        self.parentDecoder = decoder
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key>
    where Key: CodingKey {
        let container = KDLDictionaryKeyedDecodingContainer<Key>(
            properties: properties,
            decoder: parentDecoder,
            codingPath: codingPath
        )
        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            [Any].self,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Cannot decode unkeyed container from dictionary properties"
            ))
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        throw DecodingError.typeMismatch(
            Any.self,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Cannot decode single value from dictionary properties"
            ))
    }
}

// MARK: - Dictionary Keyed Container

private struct KDLDictionaryKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K

    let properties: [String: KDLValue]
    let decoder: _KDLDecoder
    var codingPath: [CodingKey]

    var allKeys: [K] {
        return properties.keys.compactMap { K(stringValue: $0) }
    }

    func contains(_ key: K) -> Bool {
        return properties[key.stringValue] != nil
    }

    func decodeNil(forKey key: K) throws -> Bool {
        guard let value = properties[key.stringValue] else {
            return true  // Key not found means nil
        }
        return value == .null
    }

    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T: Decodable {
        guard let value = properties[key.stringValue] else {
            throw DecodingError.keyNotFound(
                key,
                DecodingError.Context(
                    codingPath: codingPath,
                    debugDescription: "No value associated with key \(key.stringValue)"
                ))
        }

        let primitiveDecoder = KDLPrimitiveDecoder(
            value: value,
            decoder: decoder,
            codingPath: codingPath + [key]
        )
        return try T(from: primitiveDecoder)
    }

    func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: K) throws
    -> KeyedDecodingContainer<NestedKey> where NestedKey: CodingKey {
        throw DecodingError.typeMismatch(
            [String: Any].self,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Cannot decode nested keyed container from dictionary properties"
            ))
    }

    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        throw DecodingError.typeMismatch(
            [Any].self,
            DecodingError.Context(
                codingPath: codingPath,
                debugDescription: "Cannot decode nested unkeyed container from dictionary properties"
            ))
    }

    func superDecoder() throws -> Decoder {
        return decoder
    }

    func superDecoder(forKey key: K) throws -> Decoder {
        return decoder
    }
}
