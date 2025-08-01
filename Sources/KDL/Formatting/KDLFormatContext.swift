//
//  KDLFormatContext.swift
//  node.builders
//
//  Format context for preserving formatting during encoding/decoding round trips
//

import Foundation

/// Context for preserving formatting information during encoding/decoding round trips
public struct KDLFormatContext {
    internal let originalDocument: KDLDocument
    internal let capturedAt: Date

    init(originalDocument: KDLDocument) {
        self.originalDocument = originalDocument
        self.capturedAt = Date()
    }

    /// The date this context was captured
    public var timestamp: Date { capturedAt }

    /// Whether this context contains valid formatting information
    public var isValid: Bool { true }
}
