//
//  KDLEncoder.swift
//  KDL
//
//  Encoder for converting Swift types to KDL documents
//

import Foundation

/// An encoder that converts Swift types conforming to `Encodable` to KDL documents.
///
/// `KDLEncoder` provides seamless integration with Swift's `Codable` system, allowing you to
/// encode Swift structs, classes, and enums directly to KDL format.
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
/// let config = ServerConfig(host: "localhost", port: 8080, secure: true)
/// let encoder = KDLEncoder()
/// let kdl = try encoder.encodeToString(config)
/// ```
///
/// ## Configuration Options
///
/// The encoder provides several strategies for controlling the output format:
///
/// - ``keyEncodingStrategy``: How to convert Swift property names to KDL node names
/// - ``arrayEncodingStrategy``: How to encode arrays (as child nodes or arguments)
/// - ``dateEncodingStrategy``: How to encode date values
/// - ``nilEncodingStrategy``: Whether to include or omit nil values
/// - ``formatOptions``: Control output formatting like indentation and spacing
///
/// ## Array Encoding
///
/// Arrays can be encoded in different ways depending on the ``arrayEncodingStrategy``:
///
/// ```swift
/// // With .childNodes (default):
/// // tags {
/// //     - "swift"
/// //     - "kdl"
/// // }
///
/// // With .arguments:
/// // tags "swift" "kdl"
/// ```
///
/// ## Format Preservation
///
/// When created with a ``KDLFormatContext``, the encoder preserves the original formatting:
///
/// ```swift
/// let decoder = KDLDecoder()
/// decoder.preservesFormat = true
/// let config = try decoder.decode(MyConfig.self, from: originalKDL)
///
/// let encoder = KDLEncoder(formatContext: decoder.capturedFormatContext!)
/// let preservedKDL = try encoder.encodeToString(config)
/// ```
public class KDLEncoder {
    /// The format context to use for preservation
    public let formatContext: KDLFormatContext?

    /// User-provided information to be made available during encoding
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    /// The strategy to use for encoding keys
    public var keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys

    /// The strategy to use for encoding dates
    public var dateEncodingStrategy: DateEncodingStrategy = .iso8601

    /// The strategy to use for encoding arrays
    public var arrayEncodingStrategy: ArrayEncodingStrategy = .childNodes

    /// The strategy to use for nil values
    public var nilEncodingStrategy: NilEncodingStrategy = .includeAsNull

    /// The strategy to use for non-conforming floating-point values
    public var nonConformingFloatEncodingStrategy: NonConformingFloatEncodingStrategy = .throw

    /// KDL version to encode as (default: v2)
    public var version: KDLVersion = .v2

    /// Format options for the encoder
    public var formatOptions: KDLFormatOptions = KDLFormatOptions()

    /// Initialize without format preservation
    public init() {
        self.formatContext = nil
    }

    /// Initialize with format preservation
    public init(formatContext: KDLFormatContext) {
        self.formatContext = formatContext
    }

    /// Encodes a value as KDL data
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        let string = try encodeToString(value)
        guard let data = string.data(using: .utf8) else {
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: [],
                    debugDescription: "Unable to encode KDL string as UTF-8 data"
                ))
        }
        return data
    }

    /// Encodes a value as a KDL string
    public func encodeToString<T: Encodable>(_ value: T) throws -> String {
        let encoder = _KDLEncoder(
            keyEncodingStrategy: keyEncodingStrategy,
            dateEncodingStrategy: dateEncodingStrategy,
            arrayEncodingStrategy: arrayEncodingStrategy,
            nilEncodingStrategy: nilEncodingStrategy,
            nonConformingFloatEncodingStrategy: nonConformingFloatEncodingStrategy,
            userInfo: userInfo,
            formatContext: formatContext
        )

        try value.encode(to: encoder)

        let document = encoder.buildDocument()

        var options = formatOptions
        if options.version == .auto {
            options.version = version
        }

        let formatter = KDLFormatter(options: options)
        return formatter.format(document)
    }
}

// MARK: - Encoding Strategies

extension KDLEncoder {
    /// The strategy to use for encoding keys
    public enum KeyEncodingStrategy {
        /// Use the keys specified by each type
        case useDefaultKeys
        /// Convert from camelCase to kebab-case
        case convertToKebabCase
        /// Provide a custom conversion from the key in the encoded type to the key in the KDL
        case custom((String) -> String)
    }

    /// The strategy to use for encoding dates
    public enum DateEncodingStrategy {
        /// Defer to Date for choosing an encoding
        case deferredToDate
        /// Encode dates as ISO8601 strings
        case iso8601
        /// Encode dates as seconds since 1970
        case secondsSince1970
        /// Encode dates as milliseconds since 1970
        case millisecondsSince1970
        /// Encode dates using a custom function
        case custom((Date, Encoder) throws -> Void)
    }

    /// The strategy to use for encoding arrays
    public enum ArrayEncodingStrategy {
        /// Encode arrays as child nodes (default)
        case childNodes
        /// Encode arrays as arguments
        case arguments
    }

    /// The strategy to use for nil values
    public enum NilEncodingStrategy {
        /// Include nil values as null (default)
        case includeAsNull
        /// Omit nil values entirely
        case omit
    }

    /// The strategy to use for non-conforming floating-point values
    public enum NonConformingFloatEncodingStrategy {
        /// Throw an error
        case `throw`
        /// Convert to string using the provided representations
        case convertToString(positiveInfinity: String, negativeInfinity: String, nan: String)
    }
}

// MARK: - Internal Encoder Implementation

private class _KDLEncoder: Encoder {
    let keyEncodingStrategy: KDLEncoder.KeyEncodingStrategy
    let dateEncodingStrategy: KDLEncoder.DateEncodingStrategy
    let arrayEncodingStrategy: KDLEncoder.ArrayEncodingStrategy
    let nilEncodingStrategy: KDLEncoder.NilEncodingStrategy
    let nonConformingFloatEncodingStrategy: KDLEncoder.NonConformingFloatEncodingStrategy
    let formatContext: KDLFormatContext?

    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any]

    private var nodes: [KDLNode] = []

    init(
        keyEncodingStrategy: KDLEncoder.KeyEncodingStrategy,
        dateEncodingStrategy: KDLEncoder.DateEncodingStrategy,
        arrayEncodingStrategy: KDLEncoder.ArrayEncodingStrategy,
        nilEncodingStrategy: KDLEncoder.NilEncodingStrategy,
        nonConformingFloatEncodingStrategy: KDLEncoder.NonConformingFloatEncodingStrategy,
        userInfo: [CodingUserInfoKey: Any],
        formatContext: KDLFormatContext?,
        codingPath: [CodingKey] = []
    ) {
        self.keyEncodingStrategy = keyEncodingStrategy
        self.dateEncodingStrategy = dateEncodingStrategy
        self.arrayEncodingStrategy = arrayEncodingStrategy
        self.nilEncodingStrategy = nilEncodingStrategy
        self.nonConformingFloatEncodingStrategy = nonConformingFloatEncodingStrategy
        self.userInfo = userInfo
        self.formatContext = formatContext
        self.codingPath = codingPath
    }

    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        let container = KDLKeyedEncodingContainer<Key>(encoder: self)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        return KDLUnkeyedEncodingContainer(encoder: self)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return KDLSingleValueEncodingContainer(encoder: self)
    }

    func buildDocument() -> KDLDocument {
        return KDLDocument(nodes: nodes)
    }

    func addNode(_ node: KDLNode) {
        nodes.append(node)
    }

    func encodeKey(_ key: String) -> String {
        switch keyEncodingStrategy {
        case .useDefaultKeys:
            return key
        case .convertToKebabCase:
            return convertCamelCaseToKebabCase(key)
        case .custom(let converter):
            return converter(key)
        }
    }

    private func convertCamelCaseToKebabCase(_ string: String) -> String {
        var result = ""
        for (index, character) in string.enumerated() {
            if character.isUppercase && index > 0 {
                result += "-"
            }
            result += character.lowercased()
        }
        return result
    }
}

// MARK: - Keyed Encoding Container

private struct KDLKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: _KDLEncoder
    var codingPath: [CodingKey] { encoder.codingPath }

    init(encoder: _KDLEncoder) {
        self.encoder = encoder
    }

    mutating func encodeNil(forKey key: Key) throws {
        switch encoder.nilEncodingStrategy {
        case .includeAsNull:
            let encodedKey = encoder.encodeKey(key.stringValue)
            let node = KDLNode(name: encodedKey, arguments: [.null])
            encoder.addNode(node)
        case .omit:
            // Do nothing - omit the key entirely
            break
        }
    }

    mutating func encode(_ value: Bool, forKey key: Key) throws {
        let encodedKey = encoder.encodeKey(key.stringValue)
        let node = KDLNode(name: encodedKey, arguments: [.boolean(value)])
        encoder.addNode(node)
    }

    mutating func encode(_ value: String, forKey key: Key) throws {
        let encodedKey = encoder.encodeKey(key.stringValue)
        let node = KDLNode(name: encodedKey, arguments: [.string(value)])
        encoder.addNode(node)
    }

    mutating func encode(_ value: Double, forKey key: Key) throws {
        let encodedKey = encoder.encodeKey(key.stringValue)
        let kdlValue = try encodeFloatingPoint(value)
        let node = KDLNode(name: encodedKey, arguments: [kdlValue])
        encoder.addNode(node)
    }

    mutating func encode(_ value: Float, forKey key: Key) throws {
        try encode(Double(value), forKey: key)
    }

    mutating func encode(_ value: Int, forKey key: Key) throws {
        let encodedKey = encoder.encodeKey(key.stringValue)
        let node = KDLNode(name: encodedKey, arguments: [.integer(Int64(value))])
        encoder.addNode(node)
    }

    mutating func encode(_ value: Int8, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    mutating func encode(_ value: Int16, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    mutating func encode(_ value: Int32, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    mutating func encode(_ value: Int64, forKey key: Key) throws {
        let encodedKey = encoder.encodeKey(key.stringValue)
        let node = KDLNode(name: encodedKey, arguments: [.integer(value)])
        encoder.addNode(node)
    }

    mutating func encode(_ value: UInt, forKey key: Key) throws {
        try encode(Int64(value), forKey: key)
    }

    mutating func encode(_ value: UInt8, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    mutating func encode(_ value: UInt16, forKey key: Key) throws {
        try encode(Int(value), forKey: key)
    }

    mutating func encode(_ value: UInt32, forKey key: Key) throws {
        try encode(Int64(value), forKey: key)
    }

    mutating func encode(_ value: UInt64, forKey key: Key) throws {
        try encode(Int64(value), forKey: key)
    }

    mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
        let encodedKey = encoder.encodeKey(key.stringValue)
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }

        if let date = value as? Date {
            try encodeDate(date, forKey: encodedKey)
            return
        }

        // Arrays and collections will be handled by the unkeyed container

        // For nested objects, create a child encoder
        let childEncoder = _KDLEncoder(
            keyEncodingStrategy: encoder.keyEncodingStrategy,
            dateEncodingStrategy: encoder.dateEncodingStrategy,
            arrayEncodingStrategy: encoder.arrayEncodingStrategy,
            nilEncodingStrategy: encoder.nilEncodingStrategy,
            nonConformingFloatEncodingStrategy: encoder.nonConformingFloatEncodingStrategy,
            userInfo: encoder.userInfo,
            formatContext: encoder.formatContext,
            codingPath: encoder.codingPath
        )

        try value.encode(to: childEncoder)
        let childDocument = childEncoder.buildDocument()

        if childDocument.nodes.isEmpty {
            // Simple value - encode as single value
            let singleValueEncoder = _KDLEncoder(
                keyEncodingStrategy: encoder.keyEncodingStrategy,
                dateEncodingStrategy: encoder.dateEncodingStrategy,
                arrayEncodingStrategy: encoder.arrayEncodingStrategy,
                nilEncodingStrategy: encoder.nilEncodingStrategy,
                nonConformingFloatEncodingStrategy: encoder.nonConformingFloatEncodingStrategy,
                userInfo: encoder.userInfo,
                formatContext: encoder.formatContext,
                codingPath: encoder.codingPath
            )

            _ = singleValueEncoder.singleValueContainer()
            try value.encode(to: singleValueEncoder)
            // This will be handled by the single value container
        } else {
            // Complex object - create node with children
            let node = KDLNode(name: encodedKey, children: childDocument.nodes)
            encoder.addNode(node)
        }
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key)
    -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        encoder.codingPath.append(key)

        let childEncoder = _KDLEncoder(
            keyEncodingStrategy: encoder.keyEncodingStrategy,
            dateEncodingStrategy: encoder.dateEncodingStrategy,
            arrayEncodingStrategy: encoder.arrayEncodingStrategy,
            nilEncodingStrategy: encoder.nilEncodingStrategy,
            nonConformingFloatEncodingStrategy: encoder.nonConformingFloatEncodingStrategy,
            userInfo: encoder.userInfo,
            formatContext: encoder.formatContext,
            codingPath: encoder.codingPath
        )

        let container = KDLKeyedEncodingContainer<NestedKey>(encoder: childEncoder)
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        encoder.codingPath.append(key)
        return KDLUnkeyedEncodingContainer(encoder: encoder)
    }

    mutating func superEncoder() -> Encoder {
        return encoder
    }

    mutating func superEncoder(forKey key: Key) -> Encoder {
        encoder.codingPath.append(key)
        return encoder
    }

    private mutating func encodeDate(_ date: Date, forKey key: String) throws {
        switch encoder.dateEncodingStrategy {
        case .deferredToDate:
            let node = KDLNode(name: key, arguments: [.string(date.description)])
            encoder.addNode(node)
        case .iso8601:
            let formatter = ISO8601DateFormatter()
            let node = KDLNode(name: key, arguments: [.string(formatter.string(from: date))])
            encoder.addNode(node)
        case .secondsSince1970:
            let node = KDLNode(name: key, arguments: [.decimal(date.timeIntervalSince1970)])
            encoder.addNode(node)
        case .millisecondsSince1970:
            let node = KDLNode(name: key, arguments: [.decimal(date.timeIntervalSince1970 * 1000)])
            encoder.addNode(node)
        case .custom(let closure):
            try closure(date, encoder)
        }
    }

    private mutating func encodeArray(_ array: [Any], forKey key: String) throws {
        switch encoder.arrayEncodingStrategy {
        case .childNodes:
            let children = try array.enumerated().map { _, element -> KDLNode in
                if let stringElement = element as? String {
                    return KDLNode(name: "-", arguments: [.string(stringElement)])
                } else if let intElement = element as? Int {
                    return KDLNode(name: "-", arguments: [.integer(Int64(intElement))])
                } else if let boolElement = element as? Bool {
                    return KDLNode(name: "-", arguments: [.boolean(boolElement)])
                } else if let doubleElement = element as? Double {
                    let kdlValue = try encodeFloatingPoint(doubleElement)
                    return KDLNode(name: "-", arguments: [kdlValue])
                } else {
                    // For complex objects, we'd need to encode them properly
                    // This is a simplified implementation
                    return KDLNode(name: "-", arguments: [.string(String(describing: element))])
                }
            }
            let node = KDLNode(name: key, children: children)
            encoder.addNode(node)
        case .arguments:
            let arguments = try array.map { element -> KDLValue in
                if let stringElement = element as? String {
                    return .string(stringElement)
                } else if let intElement = element as? Int {
                    return .integer(Int64(intElement))
                } else if let boolElement = element as? Bool {
                    return .boolean(boolElement)
                } else if let doubleElement = element as? Double {
                    return try encodeFloatingPoint(doubleElement)
                } else {
                    return .string(String(describing: element))
                }
            }
            let node = KDLNode(name: key, arguments: arguments)
            encoder.addNode(node)
        }
    }

    private func encodeFloatingPoint(_ value: Double) throws -> KDLValue {
        // Always encode as decimal - let the formatter handle special values
        return .decimal(value)
    }
}

// MARK: - Unkeyed Encoding Container

private struct KDLUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let encoder: _KDLEncoder
    var codingPath: [CodingKey] { encoder.codingPath }
    var count: Int = 0

    init(encoder: _KDLEncoder) {
        self.encoder = encoder
    }

    mutating func encodeNil() throws {
        let key = IndexKey(index: count)
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }

        switch encoder.nilEncodingStrategy {
        case .includeAsNull:
            let node = KDLNode(name: "-", arguments: [.null])
            encoder.addNode(node)
        case .omit:
            // Do nothing
            break
        }
        count += 1
    }

    mutating func encode(_ value: Bool) throws {
        let key = IndexKey(index: count)
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }

        let node = KDLNode(name: "-", arguments: [.boolean(value)])
        encoder.addNode(node)
        count += 1
    }

    mutating func encode(_ value: String) throws {
        let key = IndexKey(index: count)
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }

        let node = KDLNode(name: "-", arguments: [.string(value)])
        encoder.addNode(node)
        count += 1
    }

    mutating func encode(_ value: Double) throws {
        let key = IndexKey(index: count)
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }

        let kdlValue = try encodeFloatingPoint(value)
        let node = KDLNode(name: "-", arguments: [kdlValue])
        encoder.addNode(node)
        count += 1
    }

    mutating func encode(_ value: Float) throws {
        try encode(Double(value))
    }

    mutating func encode(_ value: Int) throws {
        let key = IndexKey(index: count)
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }

        let node = KDLNode(name: "-", arguments: [.integer(Int64(value))])
        encoder.addNode(node)
        count += 1
    }

    mutating func encode(_ value: Int8) throws {
        try encode(Int(value))
    }

    mutating func encode(_ value: Int16) throws {
        try encode(Int(value))
    }

    mutating func encode(_ value: Int32) throws {
        try encode(Int(value))
    }

    mutating func encode(_ value: Int64) throws {
        let key = IndexKey(index: count)
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }

        let node = KDLNode(name: "-", arguments: [.integer(value)])
        encoder.addNode(node)
        count += 1
    }

    mutating func encode(_ value: UInt) throws {
        try encode(Int64(value))
    }

    mutating func encode(_ value: UInt8) throws {
        try encode(Int(value))
    }

    mutating func encode(_ value: UInt16) throws {
        try encode(Int(value))
    }

    mutating func encode(_ value: UInt32) throws {
        try encode(Int64(value))
    }

    mutating func encode(_ value: UInt64) throws {
        try encode(Int64(value))
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        let key = IndexKey(index: count)
        encoder.codingPath.append(key)
        defer { encoder.codingPath.removeLast() }

        if let date = value as? Date {
            try encodeDate(date)
            count += 1
            return
        }

        let childEncoder = _KDLEncoder(
            keyEncodingStrategy: encoder.keyEncodingStrategy,
            dateEncodingStrategy: encoder.dateEncodingStrategy,
            arrayEncodingStrategy: encoder.arrayEncodingStrategy,
            nilEncodingStrategy: encoder.nilEncodingStrategy,
            nonConformingFloatEncodingStrategy: encoder.nonConformingFloatEncodingStrategy,
            userInfo: encoder.userInfo,
            formatContext: encoder.formatContext,
            codingPath: encoder.codingPath
        )

        try value.encode(to: childEncoder)
        let childDocument = childEncoder.buildDocument()

        if childDocument.nodes.count == 1 && childDocument.nodes[0].children.isEmpty {
            // Simple value - change the node name to "-" for array elements
            let originalNode = childDocument.nodes[0]
            let arrayNode = KDLNode(
                name: "-",
                typeAnnotation: originalNode.typeAnnotation,
                arguments: originalNode.arguments,
                properties: originalNode.properties,
                children: originalNode.children,
                location: originalNode.location
            )
            encoder.addNode(arrayNode)
        } else {
            // Complex object - convert child nodes to properties on the "-" node
            var properties: [String: KDLValue] = [:]
            for childNode in childDocument.nodes {
                if childNode.arguments.count == 1 {
                    properties[childNode.name] = childNode.arguments[0]
                }
            }
            let node = KDLNode(name: "-", properties: properties)
            encoder.addNode(node)
        }
        count += 1
    }

    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type)
    -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
        let key = IndexKey(index: count)
        encoder.codingPath.append(key)
        count += 1

        let childEncoder = _KDLEncoder(
            keyEncodingStrategy: encoder.keyEncodingStrategy,
            dateEncodingStrategy: encoder.dateEncodingStrategy,
            arrayEncodingStrategy: encoder.arrayEncodingStrategy,
            nilEncodingStrategy: encoder.nilEncodingStrategy,
            nonConformingFloatEncodingStrategy: encoder.nonConformingFloatEncodingStrategy,
            userInfo: encoder.userInfo,
            formatContext: encoder.formatContext,
            codingPath: encoder.codingPath
        )

        let container = KDLKeyedEncodingContainer<NestedKey>(encoder: childEncoder)
        return KeyedEncodingContainer(container)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let key = IndexKey(index: count)
        encoder.codingPath.append(key)
        count += 1

        return KDLUnkeyedEncodingContainer(encoder: encoder)
    }

    mutating func superEncoder() -> Encoder {
        let key = IndexKey(index: count)
        encoder.codingPath.append(key)
        count += 1
        return encoder
    }

    private mutating func encodeDate(_ date: Date) throws {
        switch encoder.dateEncodingStrategy {
        case .deferredToDate:
            let node = KDLNode(name: "-", arguments: [.string(date.description)])
            encoder.addNode(node)
        case .iso8601:
            let formatter = ISO8601DateFormatter()
            let node = KDLNode(name: "-", arguments: [.string(formatter.string(from: date))])
            encoder.addNode(node)
        case .secondsSince1970:
            let node = KDLNode(name: "-", arguments: [.decimal(date.timeIntervalSince1970)])
            encoder.addNode(node)
        case .millisecondsSince1970:
            let node = KDLNode(name: "-", arguments: [.decimal(date.timeIntervalSince1970 * 1000)])
            encoder.addNode(node)
        case .custom(let closure):
            try closure(date, encoder)
        }
    }

    private func encodeFloatingPoint(_ value: Double) throws -> KDLValue {
        // Always encode as decimal - let the formatter handle special values
        return .decimal(value)
    }
}

// MARK: - Single Value Encoding Container

private struct KDLSingleValueEncodingContainer: SingleValueEncodingContainer {
    let encoder: _KDLEncoder
    var codingPath: [CodingKey] { encoder.codingPath }

    init(encoder: _KDLEncoder) {
        self.encoder = encoder
    }

    mutating func encodeNil() throws {
        // This should only be called at top level
        let node = KDLNode(name: "value", arguments: [.null])
        encoder.addNode(node)
    }

    mutating func encode(_ value: Bool) throws {
        let node = KDLNode(name: "value", arguments: [.boolean(value)])
        encoder.addNode(node)
    }

    mutating func encode(_ value: String) throws {
        let node = KDLNode(name: "value", arguments: [.string(value)])
        encoder.addNode(node)
    }

    mutating func encode(_ value: Double) throws {
        let kdlValue = try encodeFloatingPoint(value)
        let node = KDLNode(name: "value", arguments: [kdlValue])
        encoder.addNode(node)
    }

    mutating func encode(_ value: Float) throws {
        try encode(Double(value))
    }

    mutating func encode(_ value: Int) throws {
        let node = KDLNode(name: "value", arguments: [.integer(Int64(value))])
        encoder.addNode(node)
    }

    mutating func encode(_ value: Int8) throws {
        try encode(Int(value))
    }

    mutating func encode(_ value: Int16) throws {
        try encode(Int(value))
    }

    mutating func encode(_ value: Int32) throws {
        try encode(Int(value))
    }

    mutating func encode(_ value: Int64) throws {
        let node = KDLNode(name: "value", arguments: [.integer(value)])
        encoder.addNode(node)
    }

    mutating func encode(_ value: UInt) throws {
        try encode(Int64(value))
    }

    mutating func encode(_ value: UInt8) throws {
        try encode(Int(value))
    }

    mutating func encode(_ value: UInt16) throws {
        try encode(Int(value))
    }

    mutating func encode(_ value: UInt32) throws {
        try encode(Int64(value))
    }

    mutating func encode(_ value: UInt64) throws {
        try encode(Int64(value))
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        if let date = value as? Date {
            try encodeDate(date)
            return
        }

        try value.encode(to: encoder)
    }

    private mutating func encodeDate(_ date: Date) throws {
        switch encoder.dateEncodingStrategy {
        case .deferredToDate:
            let node = KDLNode(name: "value", arguments: [.string(date.description)])
            encoder.addNode(node)
        case .iso8601:
            let formatter = ISO8601DateFormatter()
            let node = KDLNode(name: "value", arguments: [.string(formatter.string(from: date))])
            encoder.addNode(node)
        case .secondsSince1970:
            let node = KDLNode(name: "value", arguments: [.decimal(date.timeIntervalSince1970)])
            encoder.addNode(node)
        case .millisecondsSince1970:
            let node = KDLNode(name: "value", arguments: [.decimal(date.timeIntervalSince1970 * 1000)])
            encoder.addNode(node)
        case .custom(let closure):
            try closure(date, encoder)
        }
    }

    private func encodeFloatingPoint(_ value: Double) throws -> KDLValue {
        // Always encode as decimal - let the formatter handle special values
        return .decimal(value)
    }
}

// MARK: - Supporting Types

private struct IndexKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = Int(stringValue)
    }

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }

    init(index: Int) {
        self.intValue = index
        self.stringValue = String(index)
    }
}
