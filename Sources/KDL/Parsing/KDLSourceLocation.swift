//
//  KDLSourceLocation.swift
//  node.builders
//
//  Source location information for error reporting
//

import Foundation

/// Source location information for error reporting
///
/// Tracks the position in the source text where a token or error occurred.
/// This is useful for providing helpful error messages to users.
public struct KDLSourceLocation: Equatable, Sendable {
    /// The line number (1-based)
    public let line: Int
    
    /// The column number (1-based)
    public let column: Int
    
    /// The byte offset from the start of the input
    public let offset: Int
    
    public init(line: Int, column: Int, offset: Int) {
        self.line = line
        self.column = column
        self.offset = offset
    }
}