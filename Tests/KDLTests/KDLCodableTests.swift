//
//  KDLCodableTests.swift
//  KDLTests
//
//  Tests for KDL Codable support
//

import Testing

@testable import KDL

@Suite("KDL Codable Tests")
struct KDLCodableTests {

    // MARK: - Test Types

    struct SimpleConfig: Codable, Equatable {
        let name: String
        let port: Int
        let enabled: Bool
        let ratio: Double?
    }

    struct NestedConfig: Codable, Equatable {
        let server: ServerConfig
        let database: DatabaseConfig
    }

    struct ServerConfig: Codable, Equatable {
        let host: String
        let port: Int
        let secure: Bool
    }

    struct DatabaseConfig: Codable, Equatable {
        let url: String
        let poolSize: Int
        let timeout: Double
    }

    struct ArrayConfig: Codable, Equatable {
        let tags: [String]
        let ports: [Int]
        let servers: [ServerConfig]
    }

    // MARK: - Decoder Tests

    @Test("Decode simple types")
    func testDecodeSimpleTypes() throws {
        let kdl = """
      name "test-app"
      port 8080
      enabled true
      ratio 0.75
      """

        let decoder = KDLDecoder()
        let config = try decoder.decode(SimpleConfig.self, from: kdl)

        #expect(config.name == "test-app")
        #expect(config.port == 8080)
        #expect(config.enabled == true)
        #expect(config.ratio == 0.75)
    }

    @Test("Decode with missing optional")
    func testDecodeMissingOptional() throws {
        let kdl = """
      name "test-app"
      port 8080
      enabled false
      """

        let decoder = KDLDecoder()
        let config = try decoder.decode(SimpleConfig.self, from: kdl)

        #expect(config.name == "test-app")
        #expect(config.port == 8080)
        #expect(config.enabled == false)
        #expect(config.ratio == nil)
    }

    @Test("Decode nested structures")
    func testDecodeNestedStructures() throws {
        let kdl = """
      server {
          host "localhost"
          port 3000
          secure true
      }
      database {
          url "postgresql://localhost/mydb"
          poolSize 10
          timeout 30.0
      }
      """

        let decoder = KDLDecoder()
        let config = try decoder.decode(NestedConfig.self, from: kdl)

        #expect(config.server.host == "localhost")
        #expect(config.server.port == 3000)
        #expect(config.server.secure == true)
        #expect(config.database.url == "postgresql://localhost/mydb")
        #expect(config.database.poolSize == 10)
        #expect(config.database.timeout == 30.0)
    }

    @Test("Decode arrays from child nodes")
    func testDecodeArraysFromChildNodes() throws {
        let kdl = """
      tags {
          - "swift"
          - "kdl"
          - "parser"
      }
      ports {
          - 8080
          - 8081
          - 8082
      }
      servers {
          - host="server1" port=80 secure=false
          - host="server2" port=443 secure=true
      }
      """

        let decoder = KDLDecoder()
        let config = try decoder.decode(ArrayConfig.self, from: kdl)

        #expect(config.tags == ["swift", "kdl", "parser"])
        #expect(config.ports == [8080, 8081, 8082])
        #expect(config.servers.count == 2)
        #expect(config.servers[0].host == "server1")
        #expect(config.servers[1].host == "server2")
    }

    @Test("Decode with kebab-case conversion")
    func testDecodeKebabCase() throws {
        struct KebabConfig: Codable {
            let firstName: String
            let lastName: String
            let emailAddress: String

            enum CodingKeys: String, CodingKey {
                case firstName = "first-name"
                case lastName = "last-name"
                case emailAddress = "email-address"
            }
        }

        let kdl = """
      first-name "John"
      last-name "Doe"
      email-address "john@example.com"
      """

        let decoder = KDLDecoder()
        let config = try decoder.decode(KebabConfig.self, from: kdl)

        #expect(config.firstName == "John")
        #expect(config.lastName == "Doe")
        #expect(config.emailAddress == "john@example.com")
    }

    // MARK: - Encoder Tests

    @Test("Encode simple types")
    func testEncodeSimpleTypes() throws {
        let config = SimpleConfig(
            name: "test-app",
            port: 8080,
            enabled: true,
            ratio: 0.75
        )

        let encoder = KDLEncoder()
        let kdl = try encoder.encodeToString(config)

        // Parse back to verify
        let decoder = KDLDecoder()
        let decoded = try decoder.decode(SimpleConfig.self, from: kdl)

        #expect(decoded == config)
    }

    @Test("Encode with nil omission")
    func testEncodeNilOmission() throws {
        let config = SimpleConfig(
            name: "test-app",
            port: 8080,
            enabled: false,
            ratio: nil
        )

        let encoder = KDLEncoder()
        encoder.nilEncodingStrategy = .omit
        let kdl = try encoder.encodeToString(config)

        #expect(!kdl.contains("ratio"))

        // Verify decoding
        let decoder = KDLDecoder()
        let decoded = try decoder.decode(SimpleConfig.self, from: kdl)
        #expect(decoded == config)
    }

    @Test("Encode nested structures")
    func testEncodeNestedStructures() throws {
        let config = NestedConfig(
            server: ServerConfig(host: "localhost", port: 3000, secure: true),
            database: DatabaseConfig(url: "postgresql://localhost/mydb", poolSize: 10, timeout: 30.0)
        )

        let encoder = KDLEncoder()
        let kdl = try encoder.encodeToString(config)

        // Verify by decoding
        let decoder = KDLDecoder()
        let decoded = try decoder.decode(NestedConfig.self, from: kdl)
        #expect(decoded == config)
    }

    @Test("Encode arrays")
    func testEncodeArrays() throws {
        let config = ArrayConfig(
            tags: ["swift", "kdl", "parser"],
            ports: [8080, 8081, 8082],
            servers: [
                ServerConfig(host: "server1", port: 80, secure: false),
                ServerConfig(host: "server2", port: 443, secure: true)
            ]
        )

        let encoder = KDLEncoder()
        encoder.arrayEncodingStrategy = .childNodes
        let kdl = try encoder.encodeToString(config)

        // Verify by decoding
        let decoder = KDLDecoder()
        let decoded = try decoder.decode(ArrayConfig.self, from: kdl)
        #expect(decoded == config)
    }

    // MARK: - Format Preservation Tests

    @Test("Preserve format during round-trip")
    func testFormatPreservation() throws {
        let originalKDL = """
      name "my-app"
      server {
          host "localhost"
          port 8080
          secure true
      }
      """

        let decoder = KDLDecoder()
        decoder.preservesFormat = true

        struct SimpleAppConfig: Codable {
            let name: String
            let server: ServerConfig
        }

        let config = try decoder.decode(SimpleAppConfig.self, from: originalKDL)

        // Get format context
        let formatContext = decoder.capturedFormatContext
        #expect(formatContext != nil)

        // Create encoder with format context
        let encoder = decoder.createEncoder()
        #expect(encoder.formatContext != nil)

        // For now, just verify encoding works
        let encoded = try encoder.encodeToString(config)
        #expect(!encoded.isEmpty)
    }

    // MARK: - Special Number Tests

    @Test("Encode and decode special floats")
    func testSpecialFloats() throws {
        struct FloatConfig: Codable, Equatable {
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
        let kdl = try encoder.encodeToString(config)

        #expect(kdl.contains("#inf"))
        #expect(kdl.contains("#-inf"))
        #expect(kdl.contains("#nan"))

        let decoder = KDLDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "#inf",
            negativeInfinity: "#-inf",
            nan: "#nan"
        )
        let decoded = try decoder.decode(FloatConfig.self, from: kdl)

        #expect(decoded.positive.isInfinite && decoded.positive > 0)
        #expect(decoded.negative.isInfinite && decoded.negative < 0)
        #expect(decoded.notANumber.isNaN)
    }

    // MARK: - Error Tests

    @Test("Report type mismatch")
    func testTypeMismatch() throws {
        let kdl = """
      name 123
      port "not-a-number"
      enabled "not-a-bool"
      """

        let decoder = KDLDecoder()

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(SimpleConfig.self, from: kdl)
        }
    }

    @Test("Report missing required field")
    func testMissingRequiredField() throws {
        let kdl = """
      name "test"
      enabled true
      """

        let decoder = KDLDecoder()

        #expect(throws: DecodingError.self) {
            _ = try decoder.decode(SimpleConfig.self, from: kdl)
        }
    }

    // MARK: - Real-world Example

    @Test("Encode and decode package manifest")
    func testPackageManifest() throws {
        struct Package: Codable, Equatable {
            let name: String
            let version: String
            let authors: [Author]
            let dependencies: [Dependency]
            let scripts: [String: String]
        }

        struct Author: Codable, Equatable {
            let name: String
            let email: String
        }

        struct Dependency: Codable, Equatable {
            let name: String
            let version: String
            let optional: Bool
        }

        let package = Package(
            name: "my-package",
            version: "1.0.0",
            authors: [
                Author(name: "Alice", email: "alice@example.com"),
                Author(name: "Bob", email: "bob@example.com")
            ],
            dependencies: [
                Dependency(name: "kdl", version: "^2.0.0", optional: false),
                Dependency(name: "serde", version: "1.0", optional: true)
            ],
            scripts: [
                "build": "swift build",
                "test": "swift test",
                "lint": "swiftlint"
            ]
        )

        let encoder = KDLEncoder()
        let kdl = try encoder.encodeToString(package)

        let decoder = KDLDecoder()
        let decoded = try decoder.decode(Package.self, from: kdl)

        #expect(decoded == package)
    }
}
