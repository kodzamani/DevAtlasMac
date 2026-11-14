import Foundation

// MARK: - Swift Token

struct SwiftToken {
    enum Kind: UInt8 {
        /// A name or keyword. Backticks and a leading `$` are stripped.
        case identifier
        /// An `@attribute` name, stored without the `@`.
        case attribute
        /// A single punctuation byte such as `{`, `}`, `(`, `:` or `,`.
        case punctuation
    }

    let kind: Kind
    let text: String
    let line: Int
    let column: Int
}

// MARK: - Swift Source Lexer

/// A small lexer that is just precise enough for unused-code detection.
///
/// It drops comments, the literal parts of strings (but keeps the code inside
/// `\( … )` interpolations), numbers and conditional-compilation lines, and
/// emits identifiers, attributes and punctuation with their positions.
struct SwiftSourceLexer {
    private let bytes: [UInt8]
    private var index = 0
    private var line = 1
    private var lineStart = 0
    private var tokens: [SwiftToken] = []

    private init(source: String) {
        bytes = Array(source.utf8)
    }

    static func tokenize(_ source: String) -> [SwiftToken] {
        var lexer = SwiftSourceLexer(source: source)
        lexer.lexCode(insideInterpolation: false)
        return lexer.tokens
    }

    // MARK: Code

    private mutating func lexCode(insideInterpolation: Bool) {
        var parenDepth = 0

        while index < bytes.count {
            let byte = bytes[index]

            switch byte {
            case .newline:
                consumeNewline()

            case .space, .tab, .carriageReturn:
                index += 1

            case .slash where peek(1) == .slash:
                skipToEndOfLine()

            case .slash where peek(1) == .asterisk:
                skipBlockComment()

            case .quote:
                lexString(hashCount: 0)

            case .hash:
                lexHash()

            case .at where isIdentifierStart(peek(1)):
                let column = currentColumn
                index += 1
                let name = readIdentifier()
                tokens.append(SwiftToken(kind: .attribute, text: name, line: line, column: column))

            case .backtick:
                lexBacktickIdentifier()

            case .dollar:
                index += 1
                if isIdentifierStart(peek(0)) {
                    let column = currentColumn
                    let name = readIdentifier()
                    tokens.append(SwiftToken(kind: .identifier, text: name, line: line, column: column))
                } else {
                    while index < bytes.count, isDigit(bytes[index]) { index += 1 }
                }

            case _ where isIdentifierStart(byte):
                let column = currentColumn
                let name = readIdentifier()
                tokens.append(SwiftToken(kind: .identifier, text: name, line: line, column: column))

            case _ where isDigit(byte):
                skipNumber()

            case .openParen:
                parenDepth += 1
                appendPunctuation(byte)

            case .closeParen:
                if insideInterpolation && parenDepth == 0 {
                    index += 1
                    return
                }
                parenDepth -= 1
                appendPunctuation(byte)

            default:
                appendPunctuation(byte)
            }
        }
    }

    private mutating func appendPunctuation(_ byte: UInt8) {
        tokens.append(SwiftToken(
            kind: .punctuation,
            text: String(UnicodeScalar(byte)),
            line: line,
            column: currentColumn
        ))
        index += 1
    }

    /// Handles `#"raw strings"#`, `#if` style directives and `#selector`-like macros.
    private mutating func lexHash() {
        var hashCount = 0
        while peek(hashCount) == .hash { hashCount += 1 }

        if peek(hashCount) == .quote {
            index += hashCount
            lexString(hashCount: hashCount)
            return
        }

        index += 1
        guard isIdentifierStart(peek(0)) else { return }

        let directive = readIdentifier()
        switch directive {
        case "if", "elseif", "else", "endif", "sourceLocation":
            // Conditional-compilation conditions are not code references.
            skipToEndOfLine()
        default:
            // `#selector(…)`, `#Preview { … }`, `#available(…)` and friends:
            // the arguments are lexed as ordinary code.
            break
        }
    }

    private mutating func lexBacktickIdentifier() {
        let column = currentColumn
        index += 1
        let start = index
        while index < bytes.count, bytes[index] != .backtick, bytes[index] != .newline {
            index += 1
        }
        let name = String(decoding: bytes[start..<index], as: UTF8.self)
        if peek(0) == .backtick { index += 1 }
        if !name.isEmpty {
            tokens.append(SwiftToken(kind: .identifier, text: name, line: line, column: column))
        }
    }

    // MARK: Strings

    /// Lexes a string literal starting at its opening quote. `hashCount` is the
    /// number of `#` delimiters of a raw string, which have already been consumed.
    private mutating func lexString(hashCount: Int) {
        let isMultiline = peek(1) == .quote && peek(2) == .quote
        index += isMultiline ? 3 : 1

        while index < bytes.count {
            let byte = bytes[index]

            if byte == .backslash {
                var hashes = 0
                while hashes < hashCount, peek(1 + hashes) == .hash { hashes += 1 }

                guard hashes == hashCount else {
                    index += 1
                    continue
                }

                let escaped = peek(1 + hashCount)
                if escaped == .openParen {
                    index += 2 + hashCount
                    lexCode(insideInterpolation: true)
                } else if escaped == .newline {
                    index += 1 + hashCount
                } else {
                    index += 2 + hashCount
                }
                continue
            }

            if byte == .newline {
                if !isMultiline { return }
                consumeNewline()
                continue
            }

            if byte == .quote {
                let quoteCount = isMultiline ? 3 : 1
                let closesQuotes = (0..<quoteCount).allSatisfy { peek($0) == .quote }
                let closesHashes = (0..<hashCount).allSatisfy { peek(quoteCount + $0) == .hash }
                if closesQuotes && closesHashes {
                    index += quoteCount + hashCount
                    return
                }
            }

            index += 1
        }
    }

    // MARK: Skipping

    private mutating func skipToEndOfLine() {
        while index < bytes.count, bytes[index] != .newline { index += 1 }
    }

    private mutating func skipBlockComment() {
        index += 2
        var depth = 1
        while index < bytes.count, depth > 0 {
            if bytes[index] == .slash, peek(1) == .asterisk {
                depth += 1
                index += 2
            } else if bytes[index] == .asterisk, peek(1) == .slash {
                depth -= 1
                index += 2
            } else if bytes[index] == .newline {
                consumeNewline()
            } else {
                index += 1
            }
        }
    }

    private mutating func skipNumber() {
        while index < bytes.count {
            let byte = bytes[index]
            if isIdentifierPart(byte) {
                index += 1
            } else if byte == .dot, isDigit(peek(1)) {
                index += 1
            } else {
                break
            }
        }
    }

    // MARK: Helpers

    private var currentColumn: Int { index - lineStart + 1 }

    private mutating func consumeNewline() {
        index += 1
        line += 1
        lineStart = index
    }

    private func peek(_ offset: Int) -> UInt8 {
        let position = index + offset
        return position < bytes.count ? bytes[position] : 0
    }

    private mutating func readIdentifier() -> String {
        let start = index
        while index < bytes.count, isIdentifierPart(bytes[index]) { index += 1 }
        return String(decoding: bytes[start..<index], as: UTF8.self)
    }

    private func isIdentifierStart(_ byte: UInt8) -> Bool {
        (byte >= 0x41 && byte <= 0x5A) || (byte >= 0x61 && byte <= 0x7A) || byte == .underscore || byte >= 0x80
    }

    private func isIdentifierPart(_ byte: UInt8) -> Bool {
        isIdentifierStart(byte) || isDigit(byte)
    }

    private func isDigit(_ byte: UInt8) -> Bool {
        byte >= 0x30 && byte <= 0x39
    }
}

// MARK: - Byte Constants

private extension UInt8 {
    static let newline: UInt8 = 0x0A
    static let carriageReturn: UInt8 = 0x0D
    static let space: UInt8 = 0x20
    static let tab: UInt8 = 0x09
    static let quote: UInt8 = 0x22
    static let hash: UInt8 = 0x23
    static let dollar: UInt8 = 0x24
    static let openParen: UInt8 = 0x28
    static let closeParen: UInt8 = 0x29
    static let asterisk: UInt8 = 0x2A
    static let dot: UInt8 = 0x2E
    static let slash: UInt8 = 0x2F
    static let at: UInt8 = 0x40
    static let backslash: UInt8 = 0x5C
    static let underscore: UInt8 = 0x5F
    static let backtick: UInt8 = 0x60
}
