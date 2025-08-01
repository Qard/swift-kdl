//
//  KDLToken.swift
//  node.builders
//
//  A token with its type and source location
//

import Foundation

/// A token with its type and source location
public struct KDLToken: Equatable {
    public let type: KDLTokenType
    public let location: KDLSourceLocation
    public let leadingTrivia: String // Whitespace/comments before token
    
    public init(type: KDLTokenType, location: KDLSourceLocation, leadingTrivia: String = "") {
        self.type = type
        self.location = location
        self.leadingTrivia = leadingTrivia
    }
    
    /// Check if this token represents a value
    public var isValue: Bool {
        switch type {
        case .string, .rawString, .integer, .decimal, .boolean, .null:
            return true
        default:
            return false
        }
    }
    
    /// Check if this token is a terminator
    public var isTerminator: Bool {
        switch type {
        case .semicolon, .newline, .eof:
            return true
        default:
            return false
        }
    }
    
    /// Convert token to KDLValue if possible
    public var value: KDLValue? {
        switch type {
        case .string(let str), .rawString(let str):
            return .string(str)
        case .integer(let int):
            return .integer(int)
        case .decimal(let dec):
            return .decimal(dec)
        case .boolean(let bool):
            return .boolean(bool)
        case .null:
            return .null
        default:
            return nil
        }
    }
}