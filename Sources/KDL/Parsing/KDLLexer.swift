//
//  KDLLexer.swift
//  KDL
//
//  Lexical analyzer for KDL documents with full KDL 2.0 support
//

import Foundation

/// Lexer for tokenizing KDL documents according to KDL 1.x/2.x specification
public class KDLLexer {
    private let input: String
    private var characters: [Character]
    private var position: Int = 0
    private var line: Int = 1
    private var column: Int = 1
    private var currentTrivia: String = ""
    private var detectedVersion: KDLVersion?
    private var specifiedVersion: KDLVersion
    
    /// Initialize with automatic version detection
    public init(input: String) {
        self.input = input
        self.characters = Array(input)
        self.specifiedVersion = .auto
    }
    
    /// Initialize with a specific KDL version
    public init(input: String, version: KDLVersion) {
        self.input = input
        self.characters = Array(input)
        self.specifiedVersion = version
        if version != .auto {
            self.detectedVersion = version
        }
    }
    
    /// Get the next token from the input
    public func nextToken() throws -> KDLToken {
        // Collect leading trivia (whitespace and comments)
        currentTrivia = ""
        try skipTriviaAndComments()
        
        let startLocation = currentLocation()
        
        guard !isAtEnd() else {
            return KDLToken(type: .eof, location: startLocation, leadingTrivia: currentTrivia)
        }
        
        // Check for version marker at start of document
        if position == 0 || (position < 10 && currentTrivia.isEmpty) {
            if peek() == "/" && peekNext() == "-" && peekAt(2) == " " {
                if matches("/- kdl-version ") {
                    try parseVersionMarker()
                    // Continue to get the next actual token
                    return try nextToken()
                }
            }
        }
        
        // Check for slashdash comment
        if peek() == "/" && peekNext() == "-" {
            advance() // /
            advance() // -
            return KDLToken(type: .slashdash, location: startLocation, leadingTrivia: currentTrivia)
        }
        
        let char = peek()
        
        // Check for special characters first
        switch char {
        case "{":
            advance()
            return KDLToken(type: .leftBrace, location: startLocation, leadingTrivia: currentTrivia)
        case "}":
            advance()
            return KDLToken(type: .rightBrace, location: startLocation, leadingTrivia: currentTrivia)
        case "(":
            // Type annotation
            return try lexTypeAnnotation()
        case "=":
            advance()
            return KDLToken(type: .equals, location: startLocation, leadingTrivia: currentTrivia)
        case ";":
            advance()
            return KDLToken(type: .semicolon, location: startLocation, leadingTrivia: currentTrivia)
        case "\n":
            advance()
            return KDLToken(type: .newline, location: startLocation, leadingTrivia: currentTrivia)
        case "\"":
            // Check for multi-line string
            if peekNext() == "\"" && peekAt(2) == "\"" {
                return try lexMultiLineString()
            }
            return try lexString()
        case "r":
            if peekNext() == "#" || peekNext() == "\"" {
                return try lexRawString()
            }
            return try lexIdentifier()
        case "#":
            // Check for KDL 2.0 keywords and special numbers
            if matches("#true") {
                detectVersionIfNeeded(.v2)
                return KDLToken(type: .boolean(true), location: startLocation, leadingTrivia: currentTrivia)
            } else if matches("#false") {
                detectVersionIfNeeded(.v2)
                return KDLToken(type: .boolean(false), location: startLocation, leadingTrivia: currentTrivia)
            } else if matches("#null") {
                detectVersionIfNeeded(.v2)
                return KDLToken(type: .null, location: startLocation, leadingTrivia: currentTrivia)
            } else if matches("#inf") {
                return KDLToken(type: .decimal(Double.infinity), location: startLocation, leadingTrivia: currentTrivia)
            } else if matches("#-inf") {
                return KDLToken(type: .decimal(-Double.infinity), location: startLocation, leadingTrivia: currentTrivia)
            } else if matches("#nan") {
                return KDLToken(type: .decimal(Double.nan), location: startLocation, leadingTrivia: currentTrivia)
            }
            throw KDLError.unexpectedCharacter(char, location: startLocation)
        case "-", "+":
            // Could be a sign or identifier
            if isDigit(peekNext()) || (peekNext() == "#" && (peekAt(2) == "i" || peekAt(2) == "n")) {
                return try lexNumber()
            }
            return try lexIdentifier()
        case "0"..."9":
            return try lexNumber()
        default:
            if isIdentifierStart(char) {
                return try lexIdentifier()
            }
            throw KDLError.unexpectedCharacter(char, location: startLocation)
        }
    }
    
    // MARK: - Lexing Methods
    
    private func lexString() throws -> KDLToken {
        let startLocation = currentLocation()
        advance() // Skip opening quote
        
        var value = ""
        
        while !isAtEnd() && peek() != "\"" {
            if peek() == "\\" {
                advance()
                guard !isAtEnd() else {
                    throw KDLError.unterminatedString(location: currentLocation())
                }
                
                let escaped = try lexEscapeSequence()
                value.append(escaped)
            } else if peek() == "\n" {
                throw KDLError.unterminatedString(location: currentLocation())
            } else {
                value.append(advance())
            }
        }
        
        guard !isAtEnd() else {
            throw KDLError.unterminatedString(location: currentLocation())
        }
        
        advance() // Skip closing quote
        
        return KDLToken(type: .string(value), location: startLocation, leadingTrivia: currentTrivia)
    }
    
    private func lexMultiLineString() throws -> KDLToken {
        let startLocation = currentLocation()
        advance() // First "
        advance() // Second "
        advance() // Third "
        
        // Skip newline immediately after opening quotes if present
        if peek() == "\n" {
            advance()
        }
        
        var rawValue = ""
        
        while !isAtEnd() {
            if peek() == "\"" && peekNext() == "\"" && peekAt(2) == "\"" {
                advance() // First "
                advance() // Second "
                advance() // Third "
                
                // Process the multi-line string to trim common whitespace
                let processedValue = processMultiLineString(rawValue)
                return KDLToken(type: .string(processedValue), location: startLocation, leadingTrivia: currentTrivia)
            } else if peek() == "\\" {
                advance()
                if !isAtEnd() {
                    let escaped = try lexEscapeSequence()
                    rawValue.append(escaped)
                }
            } else {
                rawValue.append(advance())
            }
        }
        
        throw KDLError.unterminatedString(location: startLocation)
    }
    
    private func processMultiLineString(_ raw: String) -> String {
        let lines = raw.components(separatedBy: "\n")
        
        // Find minimum indentation (ignoring empty lines)
        var minIndent = Int.max
        for line in lines {
            if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                let leadingWhitespace = line.prefix { $0 == " " || $0 == "\t" }
                minIndent = min(minIndent, leadingWhitespace.count)
            }
        }
        
        // If all lines are empty, return as-is
        if minIndent == Int.max {
            return raw
        }
        
        // Trim common indentation from all lines
        let trimmedLines = lines.map { line in
            if line.count >= minIndent {
                let trimmed = String(line.dropFirst(minIndent))
                // If the line becomes empty after trimming, return empty string
                return trimmed.trimmingCharacters(in: .whitespaces).isEmpty ? "" : trimmed
            }
            return line
        }
        
        return trimmedLines.joined(separator: "\n")
    }
    
    private func lexRawString() throws -> KDLToken {
        let startLocation = currentLocation()
        advance() // Skip 'r'
        
        // Count the number of '#' characters
        var hashCount = 0
        while peek() == "#" {
            advance()
            hashCount += 1
        }
        
        guard peek() == "\"" else {
            throw KDLError.unexpectedCharacter(peek(), location: currentLocation())
        }
        advance() // Skip opening quote
        
        var value = ""
        let closing = "\"" + String(repeating: "#", count: hashCount)
        
        while !isAtEnd() {
            if matches(closing) {
                return KDLToken(type: .rawString(value), location: startLocation, leadingTrivia: currentTrivia)
            }
            value.append(advance())
        }
        
        throw KDLError.unterminatedString(location: startLocation)
    }
    
    private func lexNumber() throws -> KDLToken {
        let startLocation = currentLocation()
        var numberStr = ""
        
        // Handle sign
        if peek() == "-" || peek() == "+" {
            numberStr.append(advance())
        }
        
        // Check for special numbers
        if peek() == "#" {
            if matches("#inf") {
                let sign = numberStr.starts(with: "-") ? -1.0 : 1.0
                return KDLToken(type: .decimal(sign * Double.infinity), location: startLocation, leadingTrivia: currentTrivia)
            } else if matches("#nan") {
                return KDLToken(type: .decimal(Double.nan), location: startLocation, leadingTrivia: currentTrivia)
            }
        }
        
        // Handle different number formats
        if peek() == "0" && (peekNext() == "x" || peekNext() == "o" || peekNext() == "b") {
            numberStr.append(advance()) // 0
            let base = advance() // x/o/b
            numberStr.append(base)
            
            // Consume digits with underscores
            while !isAtEnd() {
                if peek() == "_" {
                    advance() // Skip underscore
                } else if isValidDigitForBase(peek(), base: base) {
                    numberStr.append(advance())
                } else {
                    break
                }
            }
        } else {
            // Decimal number
            while !isAtEnd() && (isDigit(peek()) || peek() == "_") {
                if peek() != "_" {
                    numberStr.append(advance())
                } else {
                    advance() // Skip underscore
                }
            }
            
            // Check for decimal point or exponent
            var hasDecimalPart = false
            if peek() == "." && (isDigit(peekNext()) || peekNext() == "_") {
                hasDecimalPart = true
                numberStr.append(advance()) // .
                while !isAtEnd() && (isDigit(peek()) || peek() == "_") {
                    if peek() != "_" {
                        numberStr.append(advance())
                    } else {
                        advance() // Skip underscore
                    }
                }
            }
            
            // Check for exponent (can be present with or without decimal point)
            if peek() == "e" || peek() == "E" {
                hasDecimalPart = true // Scientific notation means it's a decimal
                numberStr.append(advance())
                if peek() == "+" || peek() == "-" {
                    numberStr.append(advance())
                }
                while !isAtEnd() && (isDigit(peek()) || peek() == "_") {
                    if peek() != "_" {
                        numberStr.append(advance())
                    } else {
                        advance() // Skip underscore
                    }
                }
            }
            
            if hasDecimalPart {
                guard let value = Double(numberStr) else {
                    throw KDLError.invalidNumber(numberStr, location: startLocation)
                }
                return KDLToken(type: .decimal(value), location: startLocation, leadingTrivia: currentTrivia)
            }
        }
        
        // Parse as integer
        let radix: Int
        var digits: String
        
        if numberStr.hasPrefix("0x") || numberStr.hasPrefix("-0x") || numberStr.hasPrefix("+0x") {
            radix = 16
            let prefixLength = numberStr.hasPrefix("-") || numberStr.hasPrefix("+") ? 3 : 2
            digits = String(numberStr.dropFirst(prefixLength))
            if numberStr.hasPrefix("-") {
                digits = "-" + digits
            }
        } else if numberStr.hasPrefix("0o") || numberStr.hasPrefix("-0o") || numberStr.hasPrefix("+0o") {
            radix = 8
            let prefixLength = numberStr.hasPrefix("-") || numberStr.hasPrefix("+") ? 3 : 2
            digits = String(numberStr.dropFirst(prefixLength))
            if numberStr.hasPrefix("-") {
                digits = "-" + digits
            }
        } else if numberStr.hasPrefix("0b") || numberStr.hasPrefix("-0b") || numberStr.hasPrefix("+0b") {
            radix = 2
            let prefixLength = numberStr.hasPrefix("-") || numberStr.hasPrefix("+") ? 3 : 2
            digits = String(numberStr.dropFirst(prefixLength))
            if numberStr.hasPrefix("-") {
                digits = "-" + digits
            }
        } else {
            radix = 10
            digits = numberStr
        }
        
        guard let value = Int64(digits, radix: radix) else {
            throw KDLError.invalidNumber(numberStr, location: startLocation)
        }
        
        return KDLToken(type: .integer(value), location: startLocation, leadingTrivia: currentTrivia)
    }
    
    private func lexIdentifier() throws -> KDLToken {
        let startLocation = currentLocation()
        var identifier = ""
        
        while !isAtEnd() && isIdentifierContinue(peek()) {
            identifier.append(advance())
        }
        
        // Check for special identifiers
        switch identifier {
        case "true":
            // Only treat as boolean in v1 or auto mode when v2 hasn't been detected
            if shouldAcceptV1Syntax() {
                detectVersionIfNeeded(.v1)
                return KDLToken(type: .boolean(true), location: startLocation, leadingTrivia: currentTrivia)
            }
        case "false":
            // Only treat as boolean in v1 or auto mode when v2 hasn't been detected
            if shouldAcceptV1Syntax() {
                detectVersionIfNeeded(.v1)
                return KDLToken(type: .boolean(false), location: startLocation, leadingTrivia: currentTrivia)
            }
        case "null":
            // Only treat as null in v1 or auto mode when v2 hasn't been detected
            if shouldAcceptV1Syntax() {
                detectVersionIfNeeded(.v1)
                return KDLToken(type: .null, location: startLocation, leadingTrivia: currentTrivia)
            }
        default:
            break
        }
        
        return KDLToken(type: .identifier(identifier), location: startLocation, leadingTrivia: currentTrivia)
    }
    
    private func lexTypeAnnotation() throws -> KDLToken {
        let startLocation = currentLocation()
        advance() // Skip (
        
        var typeName = ""
        while !isAtEnd() && peek() != ")" {
            if isIdentifierContinue(peek()) {
                typeName.append(advance())
            } else {
                throw KDLError.invalidIdentifier(String(peek()), location: currentLocation())
            }
        }
        
        guard !isAtEnd() else {
            throw KDLError.unexpectedEndOfFile
        }
        
        advance() // Skip )
        
        return KDLToken(type: .typeAnnotation(typeName), location: startLocation, leadingTrivia: currentTrivia)
    }
    
    private func lexEscapeSequence() throws -> Character {
        let char = advance()
        
        switch char {
        case "n": return "\n"
        case "r": return "\r"
        case "t": return "\t"
        case "\\": return "\\"
        case "\"": return "\""
        case "b": return "\u{08}"
        case "f": return "\u{0C}"
        case "s": return " "
        case "u":
            // Unicode escape: \u{XXXX}
            guard peek() == "{" else {
                throw KDLError.invalidEscape("\\u", location: currentLocation())
            }
            advance() // Skip {
            
            var hex = ""
            while !isAtEnd() && peek() != "}" && hex.count < 6 {
                guard isHexDigit(peek()) else {
                    throw KDLError.invalidEscape("\\u{\(hex)", location: currentLocation())
                }
                hex.append(advance())
            }
            
            guard peek() == "}" else {
                throw KDLError.invalidEscape("\\u{\(hex)", location: currentLocation())
            }
            advance() // Skip }
            
            guard let codePoint = Int(hex, radix: 16),
                  let scalar = Unicode.Scalar(codePoint) else {
                throw KDLError.invalidEscape("\\u{\(hex)}", location: currentLocation())
            }
            
            return Character(scalar)
        default:
            throw KDLError.invalidEscape("\\\(char)", location: currentLocation())
        }
    }
    
    // MARK: - Helper Methods
    
    private func skipTriviaAndComments() throws {        
        while !isAtEnd() {
            let char = peek()
            
            if char == "\n" {
                // Only skip newlines as trivia after line continuations
                if currentTrivia.hasSuffix("\\") {
                    currentTrivia.append(advance())
                } else {
                    return
                }
            } else if char == "\r" || isKDLWhitespace(char) {
                currentTrivia.append(advance())
            } else if char == "/" {
                if peekNext() == "/" {
                    try skipLineComment() 
                } else if peekNext() == "*" {
                    try skipBlockComment()
                } else {
                    return
                }
            } else if char == "\\" {
                if peekNext() == "\n" {
                    currentTrivia.append(advance()) // \
                    currentTrivia.append(advance()) // \n
                } else if peekNext() == "\r" && peekAt(2) == "\n" {
                    currentTrivia.append(advance()) // \
                    currentTrivia.append(advance()) // \r
                    currentTrivia.append(advance()) // \n
                } else {
                    return
                }
            } else {
                return
            }
        }
    }
    
    private func skipLineComment() throws {
        let triviaBeforeComment = currentTrivia
        currentTrivia.append(advance()) // /
        currentTrivia.append(advance()) // /
        
        while !isAtEnd() && peek() != "\n" {
            currentTrivia.append(advance())
        }
        
        // If this is a standalone comment (no other trivia before it), consume the newline
        // This makes the comment part of the leading trivia for the next token
        if triviaBeforeComment.isEmpty && peek() == "\n" {
            currentTrivia.append(advance())
        }
    }
    
    private func skipBlockComment() throws {
        let startLocation = currentLocation()
        currentTrivia.append(advance()) // /
        currentTrivia.append(advance()) // *
        
        var depth = 1
        
        while !isAtEnd() && depth > 0 {
            if peek() == "/" && peekNext() == "*" {
                currentTrivia.append(advance())
                currentTrivia.append(advance())
                depth += 1
            } else if peek() == "*" && peekNext() == "/" {
                currentTrivia.append(advance())
                currentTrivia.append(advance())
                depth -= 1
            } else {
                currentTrivia.append(advance())
            }
        }
        
        if depth > 0 {
            throw KDLError.unterminatedComment(location: startLocation)
        }
    }
    
    private func isIdentifierStart(_ char: Character) -> Bool {
        return char.isLetter || char == "_" || char == "-" || 
               char.isCurrencySymbol || char.unicodeScalars.first!.value > 127
    }
    
    private func isIdentifierContinue(_ char: Character) -> Bool {
        // Don't allow whitespace in identifiers
        if char == "\n" || char == "\r" || isKDLWhitespace(char) {
            return false
        }
        return isIdentifierStart(char) || char.isNumber
    }
    
    private func isDigit(_ char: Character) -> Bool {
        return char >= "0" && char <= "9"
    }
    
    private func isHexDigit(_ char: Character) -> Bool {
        return (char >= "0" && char <= "9") ||
               (char >= "a" && char <= "f") ||
               (char >= "A" && char <= "F")
    }
    
    private func isValidDigitForBase(_ char: Character, base: Character) -> Bool {
        switch base {
        case "x": return isHexDigit(char)
        case "o": return char >= "0" && char <= "7"
        case "b": return char == "0" || char == "1"
        default: return false
        }
    }
    
    private func peek() -> Character {
        return isAtEnd() ? "\0" : characters[position]
    }
    
    private func peekNext() -> Character {
        return position + 1 >= characters.count ? "\0" : characters[position + 1]
    }
    
    private func peekAt(_ offset: Int) -> Character {
        return position + offset >= characters.count ? "\0" : characters[position + offset]
    }
    
    @discardableResult
    private func advance() -> Character {
        let char = characters[position]
        position += 1
        
        if char == "\n" {
            line += 1
            column = 1
        } else {
            column += 1
        }
        
        return char
    }
    
    private func matches(_ str: String) -> Bool {
        let chars = Array(str)
        guard position + chars.count <= characters.count else { return false }
        
        for i in 0..<chars.count {
            if characters[position + i] != chars[i] {
                return false
            }
        }
        
        // Consume the matched string
        for _ in chars {
            advance()
        }
        
        return true
    }
    
    private func isAtEnd() -> Bool {
        return position >= characters.count
    }
    
    private func currentLocation() -> KDLSourceLocation {
        return KDLSourceLocation(line: line, column: column, offset: position)
    }
    
    // MARK: - Version Detection
    
    private func detectVersionIfNeeded(_ version: KDLVersion) {
        if detectedVersion == nil && specifiedVersion == .auto {
            detectedVersion = version
        }
    }
    
    // MARK: - Whitespace Helpers
    
    private func isKDLWhitespace(_ char: Character) -> Bool {
        // KDL 2.0 whitespace characters
        let whitespaceScalars: Set<Unicode.Scalar> = [
            "\u{0009}", // Character Tabulation (Tab)
            "\u{0020}", // Space
            "\u{00A0}", // No-Break Space
            "\u{1680}", // Ogham Space Mark
            "\u{2000}", // En Quad
            "\u{2001}", // Em Quad
            "\u{2002}", // En Space
            "\u{2003}", // Em Space
            "\u{2004}", // Three-Per-Em Space
            "\u{2005}", // Four-Per-Em Space
            "\u{2006}", // Six-Per-Em Space
            "\u{2007}", // Figure Space
            "\u{2008}", // Punctuation Space
            "\u{2009}", // Thin Space
            "\u{200A}", // Hair Space
            "\u{202F}", // Narrow No-Break Space
            "\u{205F}", // Medium Mathematical Space
            "\u{3000}"  // Ideographic Space
        ]
        
        // Check if the character's first scalar is in our whitespace set
        if let scalar = char.unicodeScalars.first {
            return whitespaceScalars.contains(scalar)
        }
        return false
    }
    
    private func shouldAcceptV1Syntax() -> Bool {
        if let detected = detectedVersion {
            return detected == .v1
        }
        return specifiedVersion == .v1 || specifiedVersion == .auto
    }
    
    private func parseVersionMarker() throws {
        // Already consumed "/- kdl-version "
        var versionStr = ""
        
        while !isAtEnd() && peek() != "\n" && peek() != " " {
            versionStr.append(advance())
        }
        
        switch versionStr {
        case "1":
            detectedVersion = .v1
        case "2":
            detectedVersion = .v2
        default:
            // Unknown version, continue with auto-detection
            break
        }
        
        // Skip to end of line
        while !isAtEnd() && peek() != "\n" {
            advance()
        }
        if peek() == "\n" {
            advance()
        }
    }
    
    /// Get the detected or specified KDL version
    public var version: KDLVersion {
        return detectedVersion ?? specifiedVersion
    }
}