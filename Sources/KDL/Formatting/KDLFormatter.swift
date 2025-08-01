//
//  KDLFormatter.swift
//  node.builders
//
//  Formatter for KDL documents supporting round-trip editing
//

import Foundation

/// Formatter for KDL documents
public class KDLFormatter {
    private let options: KDLFormatOptions
    private var detectedVersion: KDLVersion?

    public init(options: KDLFormatOptions = KDLFormatOptions()) {
        self.options = options
    }

    /// Format a KDL document
    public func format(_ document: KDLDocument) -> String {
        // Reset detected version for auto-detection
        if options.version == .auto {
            detectedVersion = nil
            // Scan document to detect version from boolean/null values
            detectVersionFromDocument(document)
        }

        var output = ""

        for node in document.nodes {
            output += formatNode(node, level: 0)
        }

        // Remove trailing newline
        if output.hasSuffix("\n") {
            output.removeLast()
        }

        return output
    }

    /// Format a single node
    private func formatNode(_ node: KDLNode, level: Int) -> String {
        var output = String(repeating: options.indent, count: level)

        // Node name
        output += formatIdentifier(node.name)

        // Type annotation
        if let typeAnnotation = node.typeAnnotation {
            output += "(\(typeAnnotation.name))"
        }

        // Arguments
        for argument in node.arguments {
            output += " " + formatValue(argument)
        }

        // Properties
        for (key, value) in node.properties.sorted(by: { $0.key < $1.key }) {
            output += " " + formatIdentifier(key) + "=" + formatValue(value)
        }

        // Children
        if !node.children.isEmpty {
            output += " {\n"

            for child in node.children {
                output += formatNode(child, level: level + 1)
            }

            output += String(repeating: options.indent, count: level) + "}"
        }

        // Terminator
        if options.useSemicolons {
            output += ";"
        }
        output += "\n"

        return output
    }

    /// Format an identifier
    private func formatIdentifier(_ identifier: String) -> String {
        // Check if identifier needs quoting
        let version = detectedVersion ?? options.version
        let reservedWords = version == .v2 ? ["true", "false", "null"] : []

        let needsQuoting =
            options.quoteAllIdentifiers || identifier.isEmpty
            || identifier.contains { $0.isWhitespace || $0 == "\"" || $0 == "\\" }
            || reservedWords.contains(identifier) || (identifier.first?.isNumber ?? false)

        if needsQuoting {
            return "\"" + escapeString(identifier) + "\""
        }

        return identifier
    }

    /// Format a value
    private func formatValue(_ value: KDLValue) -> String {
        switch value {
        case .string(let str):
            return "\"" + escapeString(str) + "\""
        case .integer(let int):
            return String(int)
        case .decimal(let dec):
            // Handle special float values
            if dec.isInfinite {
                return dec > 0 ? "#inf" : "#-inf"
            } else if dec.isNaN {
                return "#nan"
            }
            // Format decimal to avoid scientific notation for reasonable values
            if abs(dec) >= 0.0001 && abs(dec) < 1_000_000 {
                return String(format: "%g", dec)
            } else {
                return String(dec)
            }
        case .boolean(let bool):
            let version = detectedVersion ?? options.version
            if version == .v2 {
                return bool ? "#true" : "#false"
            } else {
                return bool ? "true" : "false"
            }
        case .null:
            let version = detectedVersion ?? options.version
            if version == .v2 {
                return "#null"
            } else {
                return "null"
            }
        }
    }

    /// Escape special characters in a string
    private func escapeString(_ str: String) -> String {
        var escaped = ""

        for char in str {
            switch char {
            case "\n": escaped += "\\n"
            case "\r": escaped += "\\r"
            case "\t": escaped += "\\t"
            case "\\": escaped += "\\\\"
            case "\"": escaped += "\\\""
            case "\u{08}": escaped += "\\b"
            case "\u{0C}": escaped += "\\f"
            default:
                if char.isASCII && char.isPrintable {
                    escaped.append(char)
                } else if char.isPrintable {
                    // Keep printable unicode characters as-is
                    escaped.append(char)
                } else {
                    // Unicode escape for non-printable characters
                    let scalar = char.unicodeScalars.first!
                    escaped += String(format: "\\u{%X}", scalar.value)
                }
            }
        }

        return escaped
    }
}

// Extension to check if character is printable
extension Character {
    fileprivate var isPrintable: Bool {
        return !isNewline && !isWhitespace || self == " "
    }
}

// MARK: - Version Detection

extension KDLFormatter {
    fileprivate func detectVersionFromDocument(_ document: KDLDocument) {
        // Already have a version
        if detectedVersion != nil { return }

        // Scan all values in document
        for node in document.nodes {
            // Check node names for v2 reserved words
            if ["true", "false", "null"].contains(node.name) {
                // These are reserved in v2, so if used as identifiers, it must be v2
                detectedVersion = .v2
                return
            }

            // Check arguments
            for arg in node.arguments {
                if case .boolean = arg, detectedVersion == nil {
                    // Boolean values exist, default to v1 for compatibility
                    detectedVersion = .v1
                    return
                } else if case .null = arg, detectedVersion == nil {
                    // Null values exist, default to v1 for compatibility
                    detectedVersion = .v1
                    return
                }
            }

            // Check properties
            for (_, value) in node.properties {
                if case .boolean = value, detectedVersion == nil {
                    detectedVersion = .v1
                    return
                } else if case .null = value, detectedVersion == nil {
                    detectedVersion = .v1
                    return
                }
            }

            // Check children recursively
            if !node.children.isEmpty {
                detectVersionFromDocument(KDLDocument(nodes: node.children))
                if detectedVersion != nil { return }
            }
        }

        // No boolean/null values found, default to v1 for backward compatibility
        if detectedVersion == nil {
            detectedVersion = .v1
        }
    }
}
