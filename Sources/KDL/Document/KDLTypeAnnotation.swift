//
//  KDLTypeAnnotation.swift
//  node.builders
//
//  Type annotations for KDL values (future KDL 2.0 support)
//

import Foundation

/// Type annotations for KDL values (future KDL 2.0 support)
public struct KDLTypeAnnotation: Equatable {
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
}