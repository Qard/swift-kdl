//
//  KDLFormatOptions.swift
//  node.builders
//
//  Options for formatting KDL documents
//

import Foundation

/// Options for formatting KDL documents
public struct KDLFormatOptions {
    /// Indentation string (default: 4 spaces)
    public var indent: String = "    "

    /// Whether to use semicolons as node terminators
    public var useSemicolons: Bool = false

    /// Whether to quote all identifiers
    public var quoteAllIdentifiers: Bool = false

    /// Maximum line length before wrapping (0 = no limit)
    public var maxLineLength: Int = 0

    /// KDL version to format as (default: auto-detect from content)
    public var version: KDLVersion = .auto

    public init() {}
}
