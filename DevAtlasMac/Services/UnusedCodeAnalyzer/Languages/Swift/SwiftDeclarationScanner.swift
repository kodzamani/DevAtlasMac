import Foundation

// MARK: - Swift Declaration Model

struct SwiftDeclaration {
    enum Kind: String {
        case `class`, `struct`, `enum`, `protocol`, actor, `typealias`
        case function, property
        case enumCase = "enum case"

        var isType: Bool {
            switch self {
            case .class, .struct, .enum, .protocol, .actor, .typealias: return true
            case .function, .property, .enumCase: return false
            }
        }
    }

    let kind: Kind
    let name: String
    let fileIndex: Int
    let line: Int
    let column: Int
    /// The container (type or extension) the declaration lives in; `nil` at file scope.
    let containerIndex: Int?
    /// For type declarations: the container their body opens.
    let ownContainerIndex: Int?
    let modifiers: Set<String>
    let attributes: Set<String>

    /// `private` / `fileprivate` without a `(set)` qualifier.
    var isFilePrivate: Bool {
        modifiers.contains("private") || modifiers.contains("fileprivate")
    }
}

struct SwiftContainer {
    enum Kind {
        case `class`, `struct`, `enum`, `protocol`, actor, `extension`
    }

    let kind: Kind
    let name: String
    let inheritance: [String]
    let attributes: Set<String>
    let fileIndex: Int
    let parentIndex: Int?
    /// Token indices of the opening and closing braces of the body.
    var bodyStart: Int?
    var bodyEnd: Int?
}

// MARK: - Swift Declaration Scanner

/// Walks token streams and records the declarations made at file and type
/// scope. Declarations inside function bodies, closures and accessors are
/// ignored on purpose — the compiler already warns about unused locals.
struct SwiftDeclarationScanner {
    private(set) var declarations: [SwiftDeclaration] = []
    private(set) var containers: [SwiftContainer] = []
    /// Names declared inside protocol bodies (requirements).
    private(set) var requirementNames: Set<String> = []
    /// Per file, token indices that are declarations or extension headers rather than references.
    private(set) var nonReferenceTokens: [Int: Set<Int>] = [:]

    private enum Scope {
        case file
        case container(Int)
        case code
    }

    private static let modifierWords: Set<String> = [
        "public", "private", "fileprivate", "internal", "open", "package",
        "static", "final", "override", "mutating", "nonmutating", "lazy",
        "weak", "unowned", "dynamic", "optional", "required", "convenience",
        "indirect", "nonisolated", "isolated", "distributed", "prefix",
        "postfix", "infix", "consuming", "borrowing", "__consuming"
    ]

    private static let typeKeywords: Set<String> = ["class", "struct", "enum", "protocol", "actor"]

    // MARK: Scanning

    mutating func scan(tokens: [SwiftToken], fileIndex: Int) {
        var scopes: [Scope] = [.file]
        var pendingContainer: Int?
        var modifiers: Set<String> = []
        var attributes: Set<String> = []
        var excluded: Set<Int> = []
        var i = 0

        func resetPrefix() {
            modifiers.removeAll(keepingCapacity: true)
            attributes.removeAll(keepingCapacity: true)
        }

        while i < tokens.count {
            let token = tokens[i]

            if token.kind == .punctuation {
                switch token.text {
                case "{":
                    if let container = pendingContainer {
                        containers[container].bodyStart = i
                        scopes.append(.container(container))
                    } else {
                        scopes.append(.code)
                    }
                    pendingContainer = nil
                    resetPrefix()
                case "}":
                    if scopes.count > 1, case .container(let container) = scopes.removeLast() {
                        containers[container].bodyEnd = i
                    }
                    resetPrefix()
                case ";":
                    resetPrefix()
                default:
                    break
                }
                i += 1
                continue
            }

            let containerIndex: Int?
            switch scopes.last ?? .file {
            case .code:
                i += 1
                continue
            case .file:
                containerIndex = nil
            case .container(let index):
                containerIndex = index
            }

            if token.kind == .attribute {
                attributes.insert(token.text)
                i = skipBalanced(tokens, from: i + 1, open: "(", close: ")")
                continue
            }

            let word = token.text

            if word == "class", !isTypeDeclaration(tokens, classKeywordAt: i) {
                modifiers.insert("class")
                i += 1
                continue
            }

            if Self.modifierWords.contains(word) {
                let hasQualifier = isPunctuation(tokens, at: i + 1, "(")
                // `private(set)` only restricts the setter: the declaration stays visible.
                modifiers.insert(hasQualifier && (word == "private" || word == "fileprivate") ? "\(word)(set)" : word)
                i = skipBalanced(tokens, from: i + 1, open: "(", close: ")")
                continue
            }

            func record(_ kind: SwiftDeclaration.Kind, nameAt nameIndex: Int, ownContainer: Int? = nil) {
                excluded.insert(nameIndex)
                let nameToken = tokens[nameIndex]

                if let containerIndex, containers[containerIndex].kind == .protocol {
                    requirementNames.insert(nameToken.text)
                    return
                }

                declarations.append(SwiftDeclaration(
                    kind: kind,
                    name: nameToken.text,
                    fileIndex: fileIndex,
                    line: nameToken.line,
                    column: nameToken.column,
                    containerIndex: containerIndex,
                    ownContainerIndex: ownContainer,
                    modifiers: modifiers,
                    attributes: attributes
                ))
            }

            switch word {
            case _ where Self.typeKeywords.contains(word):
                guard isIdentifier(tokens, at: i + 1) else { break }

                let header = parseInheritance(tokens, from: i + 2)
                let kind: (SwiftContainer.Kind, SwiftDeclaration.Kind) = switch word {
                case "class": (.class, .class)
                case "struct": (.struct, .struct)
                case "enum": (.enum, .enum)
                case "protocol": (.protocol, .protocol)
                default: (.actor, .actor)
                }

                let newContainer = containers.count
                containers.append(SwiftContainer(
                    kind: kind.0,
                    name: tokens[i + 1].text,
                    inheritance: header.names,
                    attributes: attributes,
                    fileIndex: fileIndex,
                    parentIndex: containerIndex
                ))
                // A protocol nested in a protocol is not legal Swift, so recording
                // the type in its parent's scope is always correct here.
                record(kind.1, nameAt: i + 1, ownContainer: newContainer)
                pendingContainer = newContainer
                resetPrefix()
                i = header.nextIndex
                continue

            case "extension":
                var nameIndex = i + 1
                var name = ""
                while isIdentifier(tokens, at: nameIndex) {
                    excluded.insert(nameIndex)
                    name = tokens[nameIndex].text
                    guard isPunctuation(tokens, at: nameIndex + 1, "."), isIdentifier(tokens, at: nameIndex + 2) else {
                        break
                    }
                    nameIndex += 2
                }
                guard !name.isEmpty else { break }

                let header = parseInheritance(tokens, from: nameIndex + 1)
                let newContainer = containers.count
                containers.append(SwiftContainer(
                    kind: .extension,
                    name: name,
                    inheritance: header.names,
                    attributes: attributes,
                    fileIndex: fileIndex,
                    parentIndex: containerIndex
                ))
                pendingContainer = newContainer
                resetPrefix()
                i = header.nextIndex
                continue

            case "typealias", "func":
                if isIdentifier(tokens, at: i + 1) {
                    record(word == "func" ? .function : .typealias, nameAt: i + 1)
                    resetPrefix()
                    i += 2
                    continue
                }

            case "var", "let":
                if isIdentifier(tokens, at: i + 1) {
                    record(.property, nameAt: i + 1)
                    resetPrefix()
                    i += 2
                    continue
                }

            case "case":
                guard let containerIndex, containers[containerIndex].kind == .enum else { break }

                var j = i + 1
                while isIdentifier(tokens, at: j) {
                    record(.enumCase, nameAt: j)
                    j = skipBalanced(tokens, from: j + 1, open: "(", close: ")")
                    if isPunctuation(tokens, at: j, "=") {
                        j += 1
                        while isPunctuation(tokens, at: j, "-") || isPunctuation(tokens, at: j, ".") { j += 1 }
                    }
                    guard isPunctuation(tokens, at: j, ",") else { break }
                    j += 1
                }
                resetPrefix()
                i = j
                continue

            default:
                break
            }

            // Anything else (`init`, `subscript`, type names, statements) ends the modifier run.
            resetPrefix()
            i += 1
        }

        nonReferenceTokens[fileIndex] = excluded
    }

    // MARK: Helpers

    /// `class` is a type keyword unless it is used as a modifier (`class func`, `class var`, …).
    private func isTypeDeclaration(_ tokens: [SwiftToken], classKeywordAt index: Int) -> Bool {
        guard isIdentifier(tokens, at: index + 1) else { return false }
        let next = tokens[index + 1].text
        let modifierFollowers: Set<String> = ["func", "var", "let", "subscript", "init", "typealias"]
        return !modifierFollowers.contains(next) && !Self.modifierWords.contains(next)
    }

    /// Skips generic parameters and reads the inheritance clause after a type name.
    /// Returns the index of the token that follows the clause (`{` or `where`).
    private func parseInheritance(_ tokens: [SwiftToken], from start: Int) -> (names: [String], nextIndex: Int) {
        var i = start
        if isPunctuation(tokens, at: i, "<") {
            i = skipBalanced(tokens, from: i, open: "<", close: ">")
        }
        guard isPunctuation(tokens, at: i, ":") else { return ([], i) }

        var names: [String] = []
        i += 1
        while i < tokens.count {
            let token = tokens[i]
            if token.kind == .punctuation && token.text == "{" { break }
            if token.kind == .identifier {
                if token.text == "where" { break }
                if token.text != "any" && token.text != "some" {
                    names.append(token.text)
                }
            }
            i += 1
        }
        return (names, i)
    }

    /// If the token at `start` is `open`, returns the index after its matching `close`; otherwise `start`.
    private func skipBalanced(_ tokens: [SwiftToken], from start: Int, open: String, close: String) -> Int {
        guard isPunctuation(tokens, at: start, open) else { return start }
        var depth = 0
        var i = start
        while i < tokens.count {
            let token = tokens[i]
            if token.kind == .punctuation {
                if token.text == open { depth += 1 }
                if token.text == close {
                    depth -= 1
                    if depth == 0 { return i + 1 }
                }
                // Never run past a body: protects against stray `<` comparisons.
                if token.text == "{" && open != "{" { return i }
            }
            i += 1
        }
        return i
    }

    private func isIdentifier(_ tokens: [SwiftToken], at index: Int) -> Bool {
        index < tokens.count && tokens[index].kind == .identifier
    }

    private func isPunctuation(_ tokens: [SwiftToken], at index: Int, _ text: String) -> Bool {
        index < tokens.count && tokens[index].kind == .punctuation && tokens[index].text == text
    }
}
