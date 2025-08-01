//
//  KDLTokenType.swift
//  node.builders
//
//  Token types for KDL lexing
//

import Foundation

/// Token types in KDL
public enum KDLTokenType: Equatable {
    case identifier(String)
    case string(String)
    case rawString(String)
    case integer(Int64)
    case decimal(Double)
    case boolean(Bool)
    case null
    case equals
    case leftBrace
    case rightBrace
    case semicolon
    case newline
    case eof
    case lineComment(String)
    case blockComment(String)
    case typeAnnotation(String)
    case slashdash
}
