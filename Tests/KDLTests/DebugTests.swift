//
//  DebugTests.swift
//  KDLTests
//
//  Debug tests to isolate crash issues
//

import Testing

@testable import KDL

@Suite("Debug Tests")
struct DebugTests {

    @Test("Simple array encoding")
    func testSimpleArrayEncoding() throws {
        struct SimpleConfig: Codable {
            let items: [String]
        }

        let config = SimpleConfig(items: ["a", "b", "c"])
        let encoder = KDLEncoder()
        _ = try encoder.encodeToString(config)
        // print("Simple array KDL output:")
        // print(kdl)
        // print("=======================")
    }

    @Test("Simple dictionary encoding")
    func testSimpleDictEncoding() throws {
        struct SimpleConfig: Codable {
            let dict: [String: String]
        }

        let config = SimpleConfig(dict: ["key": "value"])
        let encoder = KDLEncoder()
        _ = try encoder.encodeToString(config)
    }

    @Test("Array of custom structs")
    func testArrayOfCustomStructs() throws {
        struct Server: Codable {
            let host: String
            let port: Int
        }

        struct Config: Codable {
            let servers: [Server]
        }

        let config = Config(servers: [
            Server(host: "localhost", port: 8080),
            Server(host: "remote", port: 9090)
        ])

        let encoder = KDLEncoder()
        encoder.arrayEncodingStrategy = .childNodes
        _ = try encoder.encodeToString(config)
    }

    @Test("Try exact ArrayConfig structure")
    func testExactArrayConfig() throws {
        struct ServerConfig: Codable, Equatable {
            let host: String
            let port: Int
            let secure: Bool
        }

        struct ArrayConfig: Codable, Equatable {
            let tags: [String]
            let ports: [Int]
            let servers: [ServerConfig]
        }

        let config = ArrayConfig(
            tags: ["swift", "kdl", "parser"],
            ports: [8080, 8081, 8082],
            servers: [
                ServerConfig(host: "server1", port: 80, secure: false),
                ServerConfig(host: "server2", port: 443, secure: true)
            ]
        )

        let encoder = KDLEncoder()

        let kdl = try encoder.encodeToString(config)

        // Verify by decoding
        let decoder = KDLDecoder()
        let decoded = try decoder.decode(ArrayConfig.self, from: kdl)
        #expect(decoded == config)
    }

    @Test("Test dictionary encoding")
    func testDictEncoding() throws {
        struct Config: Codable {
            let scripts: [String: String]
        }

        let config = Config(scripts: ["build": "swift build", "test": "swift test"])

        let encoder = KDLEncoder()

        let kdl = try encoder.encodeToString(config)

        let decoder = KDLDecoder()
        _ = try decoder.decode(Config.self, from: kdl)
    }

    @Test("Test array of custom structs with dict")
    func testComplexPackage() throws {
        struct Author: Codable, Equatable {
            let name: String
            let email: String
        }

        struct Package: Codable, Equatable {
            let name: String
            let version: String
            let authors: [Author]
            let scripts: [String: String]
        }

        let package = Package(
            name: "my-package",
            version: "1.0.0",
            authors: [
                Author(name: "Alice", email: "alice@example.com"),
                Author(name: "Bob", email: "bob@example.com")
            ],
            scripts: [
                "build": "swift build",
                "test": "swift test"
            ]
        )

        let encoder = KDLEncoder()

        let kdl = try encoder.encodeToString(package)

        let decoder = KDLDecoder()
        _ = try decoder.decode(Package.self, from: kdl)
    }

    @Test("Debug simple newline")
    func testSimpleNewline() throws {
        let input = "node\nchild"

        let lexer = KDLLexer(input: input)

        var tokenCount = 0
        while true {
            let token = try lexer.nextToken()
            tokenCount += 1

            if case .eof = token.type {
                break
            }
            if tokenCount > 10 {  // Safety valve
                break
            }
        }
    }

    @Test("Debug line comment lexing")
    func testDebugLineComment() throws {
        let input = """
      node // This is a comment
      // Another comment
      child
      """

        let lexer = KDLLexer(input: input)

        var tokenCount = 0
        while true {
            let token = try lexer.nextToken()
            tokenCount += 1

            if case .eof = token.type {
                break
            }
            if tokenCount > 10 {  // Safety valve
                break
            }
        }
    }

    @Test("Debug special floats")
    func testDebugSpecialFloats() throws {
        struct FloatConfig: Codable {
            let positive: Double
            let negative: Double
            let notANumber: Double
        }

        let config = FloatConfig(
            positive: .infinity,
            negative: -.infinity,
            notANumber: .nan
        )

        let encoder = KDLEncoder()
        _ = try encoder.encodeToString(config)
        // print("Special floats KDL output:")
        // print(kdl)
        // print("=======================")
    }
}
