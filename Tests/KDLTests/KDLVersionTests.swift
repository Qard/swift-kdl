//
//  KDLVersionTests.swift
//  KDLTests
//
//  Tests for KDL 1.x and 2.x version support
//

import Testing
@testable import KDL

@Suite("KDL Version Tests")
struct KDLVersionTests {
    
    // MARK: - Version Detection Tests
    
    @Test("Auto-detect KDL 1.x from boolean values")
    func testAutoDetectV1FromBooleans() throws {
        let kdl = "node true false"
        let lexer = KDLLexer(input: kdl)
        
        let token1 = try lexer.nextToken()
        #expect(token1.type == .identifier("node"))
        
        let token2 = try lexer.nextToken()
        #expect(token2.type == .boolean(true))
        
        let token3 = try lexer.nextToken()
        #expect(token3.type == .boolean(false))
        
        #expect(lexer.version == .v1)
    }
    
    @Test("Auto-detect KDL 2.x from #boolean values")
    func testAutoDetectV2FromBooleans() throws {
        let kdl = "node #true #false"
        let lexer = KDLLexer(input: kdl)
        
        let token1 = try lexer.nextToken()
        #expect(token1.type == .identifier("node"))
        
        let token2 = try lexer.nextToken()
        #expect(token2.type == .boolean(true))
        
        let token3 = try lexer.nextToken()
        #expect(token3.type == .boolean(false))
        
        #expect(lexer.version == .v2)
    }
    
    @Test("Parse version marker")
    func testVersionMarker() throws {
        let kdl1 = "/- kdl-version 1\nnode"
        let lexer1 = KDLLexer(input: kdl1)
        
        let token1 = try lexer1.nextToken()
        #expect(token1.type == .identifier("node"))
        #expect(lexer1.version == .v1)
        
        let kdl2 = "/- kdl-version 2\nnode"
        let lexer2 = KDLLexer(input: kdl2)
        
        let token2 = try lexer2.nextToken()
        #expect(token2.type == .identifier("node"))
        #expect(lexer2.version == .v2)
    }
    
    // MARK: - Lexer Version-Specific Tests
    
    @Test("KDL 1.x treats true/false/null as keywords")
    func testV1Keywords() throws {
        let lexer = KDLLexer(input: "true false null", version: .v1)
        
        let token1 = try lexer.nextToken()
        #expect(token1.type == .boolean(true))
        
        let token2 = try lexer.nextToken()
        #expect(token2.type == .boolean(false))
        
        let token3 = try lexer.nextToken()
        #expect(token3.type == .null)
    }
    
    @Test("KDL 2.x treats true/false/null as identifiers")
    func testV2Identifiers() throws {
        let lexer = KDLLexer(input: "true false null", version: .v2)
        
        let token1 = try lexer.nextToken()
        #expect(token1.type == .identifier("true"))
        
        let token2 = try lexer.nextToken()
        #expect(token2.type == .identifier("false"))
        
        let token3 = try lexer.nextToken()
        #expect(token3.type == .identifier("null"))
    }
    
    @Test("KDL 2.x supports #true/#false/#null")
    func testV2Keywords() throws {
        let lexer = KDLLexer(input: "#true #false #null", version: .v2)
        
        let token1 = try lexer.nextToken()
        #expect(token1.type == .boolean(true))
        
        let token2 = try lexer.nextToken()
        #expect(token2.type == .boolean(false))
        
        let token3 = try lexer.nextToken()
        #expect(token3.type == .null)
    }
    
    // MARK: - Formatter Version Tests
    
    @Test("Format booleans in KDL 1.x style")
    func testFormatV1Booleans() throws {
        let document = KDLDocument(nodes: [
            KDLNode(name: "config", arguments: [.boolean(true), .boolean(false), .null])
        ])
        
        var options = KDLFormatOptions()
        options.version = .v1
        let formatter = KDLFormatter(options: options)
        let output = formatter.format(document)
        
        #expect(output == "config true false null")
    }
    
    @Test("Format booleans in KDL 2.x style")
    func testFormatV2Booleans() throws {
        let document = KDLDocument(nodes: [
            KDLNode(name: "config", arguments: [.boolean(true), .boolean(false), .null])
        ])
        
        var options = KDLFormatOptions()
        options.version = .v2
        let formatter = KDLFormatter(options: options)
        let output = formatter.format(document)
        
        #expect(output == "config #true #false #null")
    }
    
    @Test("Format reserved words as identifiers in KDL 2.x")
    func testFormatV2ReservedIdentifiers() throws {
        let document = KDLDocument(nodes: [
            KDLNode(name: "true"),
            KDLNode(name: "false"),
            KDLNode(name: "null")
        ])
        
        var options = KDLFormatOptions()
        options.version = .v2
        let formatter = KDLFormatter(options: options)
        let output = formatter.format(document)
        
        #expect(output.contains("\"true\""))
        #expect(output.contains("\"false\""))
        #expect(output.contains("\"null\""))
    }
    
    // MARK: - Parser Version Tests
    
    @Test("Parse mixed version content")
    func testParseMixedContent() throws {
        // This should auto-detect as v1 due to boolean values
        let kdl = """
        settings {
            enabled true
            disabled false
            optional null
        }
        """
        
        let document = try KDLParser.parse(kdl)
        let settings = document.nodes.first!
        #expect(settings.name == "settings")
        #expect(settings.children.count == 3)
        #expect(settings.children[0].arguments[0] == .boolean(true))
        #expect(settings.children[1].arguments[0] == .boolean(false))
        #expect(settings.children[2].arguments[0] == .null)
    }
    
    // MARK: - Codable Version Tests
    
    @Test("Encode with specific version")
    func testEncodeWithVersion() throws {
        struct Config: Codable {
            let enabled: Bool
            let disabled: Bool
            let optional: Bool?
        }
        
        let config = Config(enabled: true, disabled: false, optional: nil)
        
        // Encode as v1
        let encoder1 = KDLEncoder()
        encoder1.version = .v1
        let kdl1 = try encoder1.encodeToString(config)
        #expect(kdl1.contains("true"))
        #expect(kdl1.contains("false"))
        #expect(!kdl1.contains("#true"))
        
        // Encode as v2
        let encoder2 = KDLEncoder()
        encoder2.version = .v2
        let kdl2 = try encoder2.encodeToString(config)
        #expect(kdl2.contains("#true"))
        #expect(kdl2.contains("#false"))
        #expect(!kdl2.contains(" true"))
    }
    
    @Test("Decode both version formats")
    func testDecodeBothVersions() throws {
        struct Config: Codable, Equatable {
            let enabled: Bool
            let disabled: Bool
        }
        
        let kdl1 = "enabled true\ndisabled false"
        let kdl2 = "enabled #true\ndisabled #false"
        
        let decoder = KDLDecoder()
        
        // Should decode v1 format
        let config1 = try decoder.decode(Config.self, from: kdl1)
        #expect(config1.enabled == true)
        #expect(config1.disabled == false)
        
        // Should decode v2 format
        let config2 = try decoder.decode(Config.self, from: kdl2)
        #expect(config2.enabled == true)
        #expect(config2.disabled == false)
        
        #expect(config1 == config2)
    }
    
    // MARK: - Unicode Whitespace Tests
    
    @Test("Parse with Unicode whitespace")
    func testUnicodeWhitespace() throws {
        // Test various Unicode whitespace characters
        let spaces = [
            "\u{0009}", // Tab
            "\u{0020}", // Space
            "\u{00A0}", // No-Break Space
            "\u{2000}", // En Quad
            "\u{2003}", // Em Space
            "\u{3000}"  // Ideographic Space
        ]
        
        for space in spaces {
            let kdl = "node\(space)\"value\""
            let document = try KDLParser.parse(kdl)
            #expect(document.nodes.count == 1)
            #expect(document.nodes[0].name == "node")
            #expect(document.nodes[0].arguments.count == 1)
            #expect(document.nodes[0].arguments[0] == .string("value"))
        }
    }
}