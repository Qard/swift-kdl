//
//  KDLLexerTests.swift
//  KDLTests
//
//  Tests for the KDL lexer
//

import Testing

@testable import KDL

@Suite("KDL Lexer Tests")
struct KDLLexerTests {

    // MARK: - Basic Token Tests

    @Test("Lex simple identifiers")
    func testSimpleIdentifiers() throws {
        let lexer = KDLLexer(input: "node child-node _private")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .identifier("node"))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .identifier("child-node"))

        let token3 = try lexer.nextToken()
        #expect(token3.type == .identifier("_private"))

        let token4 = try lexer.nextToken()
        #expect(token4.type == .eof)
    }

    @Test("Lex string literals")
    func testStringLiterals() throws {
        let lexer = KDLLexer(input: #""hello" "world with spaces" "escaped\"quote""#)

        let token1 = try lexer.nextToken()
        #expect(token1.type == .string("hello"))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .string("world with spaces"))

        let token3 = try lexer.nextToken()
        #expect(token3.type == .string("escaped\"quote"))
    }

    @Test("Lex multi-line strings")
    func testMultiLineStrings() throws {
        let input = #"""
            """
            Hello
            World
            """
      """#

        let lexer = KDLLexer(input: input)
        let token = try lexer.nextToken()

        #expect(token.type == .string("Hello\nWorld\n"))
    }

    @Test("Lex raw strings")
    func testRawStrings() throws {
        let input = "r#\"C:\\path\\to\\file\"# r##\"quote\"in\"string\"##"
        let lexer = KDLLexer(input: input)

        let token1 = try lexer.nextToken()
        #expect(token1.type == .rawString("C:\\path\\to\\file"))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .rawString("quote\"in\"string"))
    }

    // MARK: - Number Tests

    @Test("Lex decimal numbers")
    func testDecimalNumbers() throws {
        let lexer = KDLLexer(input: "42 -17 3.14159 -2.5 1e10 2.5e-3")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .integer(42))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .integer(-17))

        let token3 = try lexer.nextToken()
        if case .decimal(let value) = token3.type {
            #expect(value == 3.14159)
        } else {
            Issue.record("Expected decimal token")
        }

        let token4 = try lexer.nextToken()
        if case .decimal(let value) = token4.type {
            #expect(value == -2.5)
        } else {
            Issue.record("Expected decimal token")
        }

        let token5 = try lexer.nextToken()
        if case .decimal(let value) = token5.type {
            #expect(value == 1e10)
        } else {
            Issue.record("Expected decimal token")
        }

        let token6 = try lexer.nextToken()
        if case .decimal(let value) = token6.type {
            #expect(value == 2.5e-3)
        } else {
            Issue.record("Expected decimal token")
        }
    }

    @Test("Lex numbers with underscores")
    func testNumbersWithUnderscores() throws {
        let lexer = KDLLexer(input: "1_000_000 3.141_592_653")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .integer(1_000_000))

        let token2 = try lexer.nextToken()
        if case .decimal(let value) = token2.type {
            #expect(abs(value - 3.141592653) < 0.000001)
        } else {
            Issue.record("Expected decimal token")
        }
    }

    @Test("Lex hexadecimal numbers")
    func testHexNumbers() throws {
        let lexer = KDLLexer(input: "0xDEADBEEF 0xff -0x10")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .integer(0xDEAD_BEEF))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .integer(0xff))

        let token3 = try lexer.nextToken()
        #expect(token3.type == .integer(-0x10))
    }

    @Test("Lex octal numbers")
    func testOctalNumbers() throws {
        let lexer = KDLLexer(input: "0o755 0o644 -0o10")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .integer(0o755))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .integer(0o644))

        let token3 = try lexer.nextToken()
        #expect(token3.type == .integer(-0o10))
    }

    @Test("Lex binary numbers")
    func testBinaryNumbers() throws {
        let lexer = KDLLexer(input: "0b1010 0b1111_0000 -0b101")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .integer(0b1010))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .integer(0b1111_0000))

        let token3 = try lexer.nextToken()
        #expect(token3.type == .integer(-0b101))
    }

    @Test("Lex special float values")
    func testSpecialFloats() throws {
        let lexer = KDLLexer(input: "#inf #-inf #nan +#inf -#inf")

        let token1 = try lexer.nextToken()
        if case .decimal(let value) = token1.type {
            #expect(value.isInfinite && value > 0)
        } else {
            Issue.record("Expected positive infinity")
        }

        let token2 = try lexer.nextToken()
        if case .decimal(let value) = token2.type {
            #expect(value.isInfinite && value < 0)
        } else {
            Issue.record("Expected negative infinity")
        }

        let token3 = try lexer.nextToken()
        if case .decimal(let value) = token3.type {
            #expect(value.isNaN)
        } else {
            Issue.record("Expected NaN")
        }

        let token4 = try lexer.nextToken()
        if case .decimal(let value) = token4.type {
            #expect(value.isInfinite && value > 0)
        } else {
            Issue.record("Expected positive infinity")
        }

        let token5 = try lexer.nextToken()
        if case .decimal(let value) = token5.type {
            #expect(value.isInfinite && value < 0)
        } else {
            Issue.record("Expected negative infinity")
        }
    }

    // MARK: - Boolean and Null Tests

    @Test("Lex booleans and null")
    func testBooleansAndNull() throws {
        let lexer = KDLLexer(input: "true false null")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .boolean(true))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .boolean(false))

        let token3 = try lexer.nextToken()
        #expect(token3.type == .null)
    }

    // MARK: - Special Characters

    @Test("Lex special characters")
    func testSpecialCharacters() throws {
        let lexer = KDLLexer(input: "{}=;\n")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .leftBrace)

        let token2 = try lexer.nextToken()
        #expect(token2.type == .rightBrace)

        let token3 = try lexer.nextToken()
        #expect(token3.type == .equals)

        let token4 = try lexer.nextToken()
        #expect(token4.type == .semicolon)

        let token5 = try lexer.nextToken()
        #expect(token5.type == .newline)
    }

    @Test("Lex type annotations")
    func testTypeAnnotations() throws {
        let lexer = KDLLexer(input: "(u8) (string) (my-type)")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .typeAnnotation("u8"))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .typeAnnotation("string"))

        let token3 = try lexer.nextToken()
        #expect(token3.type == .typeAnnotation("my-type"))
    }

    @Test("Lex slashdash")
    func testSlashdash() throws {
        let lexer = KDLLexer(input: "/-node /- value")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .slashdash)

        let token2 = try lexer.nextToken()
        #expect(token2.type == .identifier("node"))

        let token3 = try lexer.nextToken()
        #expect(token3.type == .slashdash)

        let token4 = try lexer.nextToken()
        #expect(token4.type == .identifier("value"))
    }

    // MARK: - Comment Tests

    @Test("Skip line comments")
    func testLineComments() throws {
        let input = """
      node // This is a comment
      // Another comment
      child
      """

        let lexer = KDLLexer(input: input)

        let token1 = try lexer.nextToken()
        #expect(token1.type == .identifier("node"))
        #expect(token1.leadingTrivia == "")

        let token2 = try lexer.nextToken()
        #expect(token2.type == .newline)

        let token3 = try lexer.nextToken()
        #expect(token3.type == .identifier("child"))
        #expect(token3.leadingTrivia.contains("// Another comment"))
    }

    @Test("Skip block comments")
    func testBlockComments() throws {
        let input = """
      node /* block comment */ child
      /* multi
         line
         comment */ value
      """

        let lexer = KDLLexer(input: input)

        let token1 = try lexer.nextToken()
        #expect(token1.type == .identifier("node"))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .identifier("child"))
        #expect(token2.leadingTrivia.contains("/* block comment */"))

        let token3 = try lexer.nextToken()
        #expect(token3.type == .newline)

        let token4 = try lexer.nextToken()
        #expect(token4.type == .identifier("value"))
        #expect(token4.leadingTrivia.contains("/* multi"))
    }

    @Test("Handle nested block comments")
    func testNestedBlockComments() throws {
        let input = "node /* outer /* inner */ still outer */ child"

        let lexer = KDLLexer(input: input)

        let token1 = try lexer.nextToken()
        #expect(token1.type == .identifier("node"))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .identifier("child"))
        #expect(token2.leadingTrivia.contains("/* outer /* inner */ still outer */"))
    }

    // MARK: - Line Continuation Tests

    @Test("Handle line continuations")
    func testLineContinuations() throws {
        let input = """
      node \
          value \
          key=val
      """

        let lexer = KDLLexer(input: input)

        let token1 = try lexer.nextToken()
        #expect(token1.type == .identifier("node"))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .identifier("value"))

        let token3 = try lexer.nextToken()
        #expect(token3.type == .identifier("key"))

        let token4 = try lexer.nextToken()
        #expect(token4.type == .equals)

        let token5 = try lexer.nextToken()
        #expect(token5.type == .identifier("val"))
    }

    // MARK: - Error Tests

    @Test("Report unterminated string")
    func testUnterminatedString() throws {
        let lexer = KDLLexer(input: #""unterminated"#)

        #expect(throws: KDLError.self) {
            _ = try lexer.nextToken()
        }
    }

    @Test("Report invalid escape sequence")
    func testInvalidEscape() throws {
        let lexer = KDLLexer(input: #""\x""#)

        #expect(throws: KDLError.self) {
            _ = try lexer.nextToken()
        }
    }

    @Test("Report unterminated block comment")
    func testUnterminatedBlockComment() throws {
        let lexer = KDLLexer(input: "/* unterminated")

        #expect(throws: KDLError.self) {
            _ = try lexer.nextToken()
        }
    }

    // MARK: - Unicode Tests

    @Test("Handle unicode identifiers")
    func testUnicodeIdentifiers() throws {
        let lexer = KDLLexer(input: "日本語 café π")

        let token1 = try lexer.nextToken()
        #expect(token1.type == .identifier("日本語"))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .identifier("café"))

        let token3 = try lexer.nextToken()
        #expect(token3.type == .identifier("π"))
    }

    @Test("Handle unicode escapes")
    func testUnicodeEscapes() throws {
        let lexer = KDLLexer(input: #""\u{1F600}" "\u{65}""#)

        let token1 = try lexer.nextToken()
        #expect(token1.type == .string("😀"))

        let token2 = try lexer.nextToken()
        #expect(token2.type == .string("e"))
    }
}
