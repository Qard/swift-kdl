//
//  KDLParserTests.swift
//  KDLTests
//
//  Tests for the KDL parser
//

import Testing
@testable import KDL

@Suite("KDL Parser Tests")
struct KDLParserTests {
    
    // MARK: - Basic Node Tests
    
    @Test("Parse simple nodes")
    func testSimpleNodes() throws {
        let input = """
        node1
        node2
        node3
        """
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 3)
        #expect(document.nodes[0].name == "node1")
        #expect(document.nodes[1].name == "node2")
        #expect(document.nodes[2].name == "node3")
    }
    
    @Test("Parse nodes with arguments")
    func testNodesWithArguments() throws {
        let input = """
        node "string" 123 true null 3.14
        """
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 1)
        let node = document.nodes[0]
        #expect(node.name == "node")
        #expect(node.arguments.count == 5)
        #expect(node.arguments[0] == .string("string"))
        #expect(node.arguments[1] == .integer(123))
        #expect(node.arguments[2] == .boolean(true))
        #expect(node.arguments[3] == .null)
        
        if case .decimal(let value) = node.arguments[4] {
            #expect(abs(value - 3.14) < 0.001)
        } else {
            Issue.record("Expected decimal value")
        }
    }
    
    @Test("Parse nodes with properties")
    func testNodesWithProperties() throws {
        let input = """
        node key1="value1" key2=42 enabled=true
        """
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 1)
        let node = document.nodes[0]
        #expect(node.name == "node")
        #expect(node.properties.count == 3)
        #expect(node.properties["key1"] == .string("value1"))
        #expect(node.properties["key2"] == .integer(42))
        #expect(node.properties["enabled"] == .boolean(true))
    }
    
    @Test("Parse nodes with mixed arguments and properties")
    func testNodesWithMixedArgumentsAndProperties() throws {
        let input = """
        node "arg1" key="value" 123 enabled=false
        """
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 1)
        let node = document.nodes[0]
        #expect(node.arguments.count == 2)
        #expect(node.arguments[0] == .string("arg1"))
        #expect(node.arguments[1] == .integer(123))
        #expect(node.properties.count == 2)
        #expect(node.properties["key"] == .string("value"))
        #expect(node.properties["enabled"] == .boolean(false))
    }
    
    // MARK: - Child Node Tests
    
    @Test("Parse nodes with children")
    func testNodesWithChildren() throws {
        let input = """
        parent {
            child1
            child2 "value"
            child3 key="value"
        }
        """
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 1)
        let parent = document.nodes[0]
        #expect(parent.name == "parent")
        #expect(parent.children.count == 3)
        #expect(parent.children[0].name == "child1")
        #expect(parent.children[1].name == "child2")
        #expect(parent.children[1].arguments[0] == .string("value"))
        #expect(parent.children[2].name == "child3")
        #expect(parent.children[2].properties["key"] == .string("value"))
    }
    
    @Test("Parse nested children")
    func testNestedChildren() throws {
        let input = """
        root {
            level1 {
                level2 {
                    level3 "deep"
                }
            }
        }
        """
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 1)
        let root = document.nodes[0]
        #expect(root.children.count == 1)
        let level1 = root.children[0]
        #expect(level1.children.count == 1)
        let level2 = level1.children[0]
        #expect(level2.children.count == 1)
        let level3 = level2.children[0]
        #expect(level3.name == "level3")
        #expect(level3.arguments[0] == .string("deep"))
    }
    
    // MARK: - Type Annotation Tests
    
    @Test("Parse type annotations")
    func testTypeAnnotations() throws {
        let input = """
        (u8)node 255
        (date)published "2024-01-01"
        (person)author name="John" age=30
        """
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 3)
        
        let node1 = document.nodes[0]
        #expect(node1.name == "node")
        #expect(node1.typeAnnotation?.name == "u8")
        #expect(node1.arguments[0] == .integer(255))
        
        let node2 = document.nodes[1]
        #expect(node2.name == "published")
        #expect(node2.typeAnnotation?.name == "date")
        
        let node3 = document.nodes[2]
        #expect(node3.name == "author")
        #expect(node3.typeAnnotation?.name == "person")
    }
    
    // MARK: - Slashdash Tests
    
    @Test("Parse slashdash comments on nodes")
    func testSlashdashNodes() throws {
        let input = """
        node1
        /-node2
        node3
        """
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 2)
        #expect(document.nodes[0].name == "node1")
        #expect(document.nodes[1].name == "node3")
    }
    
    @Test("Parse slashdash comments on arguments")
    func testSlashdashArguments() throws {
        let input = """
        node "keep" /-"skip" 123 /-456 true
        """
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 1)
        let node = document.nodes[0]
        #expect(node.arguments.count == 3)
        #expect(node.arguments[0] == .string("keep"))
        #expect(node.arguments[1] == .integer(123))
        #expect(node.arguments[2] == .boolean(true))
    }
    
    @Test("Parse slashdash comments on properties")
    func testSlashdashProperties() throws {
        let input = """
        node keep="yes" /-skip="no" also="keep"
        """
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 1)
        let node = document.nodes[0]
        #expect(node.properties.count == 2)
        #expect(node.properties["keep"] == .string("yes"))
        #expect(node.properties["also"] == .string("keep"))
        #expect(node.properties["skip"] == nil)
    }
    
    @Test("Parse slashdash comments on children")
    func testSlashdashChildren() throws {
        let input = """
        parent {
            child1
            /-child2
            child3
        }
        """
        
        let document = try KDLParser.parse(input)
        
        let parent = document.nodes[0]
        #expect(parent.children.count == 2)
        #expect(parent.children[0].name == "child1")
        #expect(parent.children[1].name == "child3")
    }
    
    // MARK: - Number Format Tests
    
    @Test("Parse various number formats")
    func testNumberFormats() throws {
        let input = """
        decimal 42 -17 3.14159
        hex 0xDEADBEEF 0xff
        octal 0o755 0o644
        binary 0b1010 0b11110000
        underscores 1_000_000 3.141_592_653
        special #inf #-inf #nan
        """
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 6)
        
        // Decimal
        let decimal = document.nodes[0]
        #expect(decimal.arguments[0] == .integer(42))
        #expect(decimal.arguments[1] == .integer(-17))
        
        // Hex
        let hex = document.nodes[1]
        #expect(hex.arguments[0] == .integer(0xDEADBEEF))
        #expect(hex.arguments[1] == .integer(0xff))
        
        // Octal
        let octal = document.nodes[2]
        #expect(octal.arguments[0] == .integer(0o755))
        
        // Binary
        let binary = document.nodes[3]
        #expect(binary.arguments[0] == .integer(0b1010))
        
        // Special floats
        let special = document.nodes[5]
        if case .decimal(let inf) = special.arguments[0] {
            #expect(inf.isInfinite && inf > 0)
        }
        if case .decimal(let ninf) = special.arguments[1] {
            #expect(ninf.isInfinite && ninf < 0)
        }
        if case .decimal(let nan) = special.arguments[2] {
            #expect(nan.isNaN)
        }
    }
    
    // MARK: - String Format Tests
    
    @Test("Parse various string formats")
    func testStringFormats() throws {
        let input = #"""
        basic "hello world"
        escapes "line1\nline2" "quote\"inside" "tab\there"
        raw r#"C:\path\to\file"#
        multiline """
            First line
            Second line
            """
        """#
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 4)
        
        let basic = document.nodes[0]
        #expect(basic.arguments[0] == .string("hello world"))
        
        let escapes = document.nodes[1]
        #expect(escapes.arguments[0] == .string("line1\nline2"))
        #expect(escapes.arguments[1] == .string("quote\"inside"))
        #expect(escapes.arguments[2] == .string("tab\there"))
        
        let raw = document.nodes[2]
        #expect(raw.arguments[0] == .string(#"C:\path\to\file"#))
        
        let multiline = document.nodes[3]
        #expect(multiline.arguments[0] == .string("First line\nSecond line\n"))
    }
    
    // MARK: - Terminator Tests
    
    @Test("Parse nodes with different terminators")
    func testTerminators() throws {
        let input = """
        node1;
        node2
        node3; node4
        node5 {
            child
        }
        """
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 5)
        #expect(document.nodes[0].name == "node1")
        #expect(document.nodes[1].name == "node2")
        #expect(document.nodes[2].name == "node3")
        #expect(document.nodes[3].name == "node4")
        #expect(document.nodes[4].name == "node5")
        #expect(document.nodes[4].children.count == 1)
    }
    
    // MARK: - Error Tests
    
    @Test("Report duplicate properties")
    func testDuplicateProperties() throws {
        let input = """
        node key="first" key="second"
        """
        
        #expect(throws: KDLError.self) {
            _ = try KDLParser.parse(input)
        }
    }
    
    @Test("Report unexpected tokens")
    func testUnexpectedTokens() throws {
        let input = """
        node =
        """
        
        #expect(throws: KDLError.self) {
            _ = try KDLParser.parse(input)
        }
    }
    
    @Test("Report unclosed children block")
    func testUnclosedChildren() throws {
        let input = """
        node {
            child
        """
        
        #expect(throws: KDLError.self) {
            _ = try KDLParser.parse(input)
        }
    }
    
    // MARK: - Real-world Examples
    
    @Test("Parse package configuration")
    func testPackageConfiguration() throws {
        let input = """
        package {
            name "my-package"
            version "1.0.0"
            authors {
                - "Alice" email="alice@example.com"
                - "Bob" email="bob@example.com"
            }
            dependencies {
                kdl "^2.0.0" optional=false
                serde "1.0" features="derive"
            }
        }
        """
        
        let document = try KDLParser.parse(input)
        
        #expect(document.nodes.count == 1)
        let package = document.nodes[0]
        #expect(package.name == "package")
        #expect(package.children.count == 4)
        
        let name = package.children[0]
        #expect(name.name == "name")
        #expect(name.arguments[0] == .string("my-package"))
        
        let authors = package.children[2]
        #expect(authors.name == "authors")
        #expect(authors.children.count == 2)
        #expect(authors.children[0].name == "-")
        #expect(authors.children[0].arguments[0] == .string("Alice"))
    }
}