//
//  KDLError.swift
//  node.builders
//
//  Error types for KDL parsing
//

import Foundation

/// Errors that can occur during KDL parsing
public enum KDLError: Error, LocalizedError {
    case unexpectedCharacter(Character, location: KDLSourceLocation)
    case unexpectedToken(String, location: KDLSourceLocation)
    case unterminatedString(location: KDLSourceLocation)
    case unterminatedComment(location: KDLSourceLocation)
    case invalidNumber(String, location: KDLSourceLocation)
    case invalidEscape(String, location: KDLSourceLocation)
    case invalidIdentifier(String, location: KDLSourceLocation)
    case unexpectedEndOfFile
    case duplicateProperty(String, location: KDLSourceLocation)
    
    public var errorDescription: String? {
        switch self {
        case .unexpectedCharacter(let char, let location):
            return "Unexpected character '\(char)' at line \(location.line), column \(location.column)"
        case .unexpectedToken(let token, let location):
            return "Unexpected token '\(token)' at line \(location.line), column \(location.column)"
        case .unterminatedString(let location):
            return "Unterminated string at line \(location.line), column \(location.column)"
        case .unterminatedComment(let location):
            return "Unterminated comment at line \(location.line), column \(location.column)"
        case .invalidNumber(let number, let location):
            return "Invalid number '\(number)' at line \(location.line), column \(location.column)"
        case .invalidEscape(let escape, let location):
            return "Invalid escape sequence '\(escape)' at line \(location.line), column \(location.column)"
        case .invalidIdentifier(let identifier, let location):
            return "Invalid identifier '\(identifier)' at line \(location.line), column \(location.column)"
        case .unexpectedEndOfFile:
            return "Unexpected end of file"
        case .duplicateProperty(let property, let location):
            return "Duplicate property '\(property)' at line \(location.line), column \(location.column)"
        }
    }
}