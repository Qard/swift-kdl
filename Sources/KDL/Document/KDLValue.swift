//
//  KDLValue.swift
//  node.builders
//
//  KDL value types supporting strings, numbers, booleans, and null
//

import Foundation

/// Represents a value in a KDL document
public enum KDLValue: Equatable, CustomStringConvertible {
    case string(String)
    case integer(Int64)
    case decimal(Double)
    case boolean(Bool)
    case null

    public var description: String {
        switch self {
        case .string(let value):
            return "\"\(value)\""
        case .integer(let value):
            return String(value)
        case .decimal(let value):
            return String(value)
        case .boolean(let value):
            return value ? "true" : "false"
        case .null:
            return "null"
        }
    }

    /// Returns the value as a string if possible
    public var stringValue: String? {
        switch self {
        case .string(let value):
            return value
        default:
            return nil
        }
    }

    /// Returns the value as an integer if possible
    public var intValue: Int64? {
        switch self {
        case .integer(let value):
            return value
        case .decimal(let value):
            return Int64(value)
        default:
            return nil
        }
    }

    /// Returns the value as a double if possible
    public var doubleValue: Double? {
        switch self {
        case .decimal(let value):
            return value
        case .integer(let value):
            return Double(value)
        default:
            return nil
        }
    }

    /// Returns the value as a boolean if possible
    public var boolValue: Bool? {
        switch self {
        case .boolean(let value):
            return value
        default:
            return nil
        }
    }

    /// Returns true if this is a null value
    public var isNull: Bool {
        switch self {
        case .null:
            return true
        default:
            return false
        }
    }
}
