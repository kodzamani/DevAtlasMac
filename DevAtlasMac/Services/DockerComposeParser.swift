import Foundation

/// A lossless block editor, deliberately not a general-purpose YAML interpreter.
/// Unsupported YAML stays editable as source instead of being normalized or discarded.
enum DockerComposeParser {
    struct Failure: LocalizedError {
        let key: String
        var errorDescription: String? { key.localized }
    }
    private struct Block {
        let key: String
        let value: String
        let range: Range<Int>
        let indent: Int
    }
    private struct Edit {
        let range: Range<Int>
        let lines: [String]
    }

    static func parse(_ source: String) -> DockerComposeDocument {
        let lines = source.components(separatedBy: "\n")
        var document = DockerComposeDocument(source: source, services: [], originalServices: [])
        guard !source.contains("\t"),
              source.range(of: "(?m)(^|\\s)[&*!][A-Za-z_]|^\\s*<<:", options: .regularExpression) == nil,
              let root = blocks(lines, in: lines.indices, indent: 0),
              let services = root.first(where: { $0.key == "services" }),
              services.value.isEmpty || services.value == "{}" else {
            document.visualUnavailable = true
            return document
        }
        let childRange = (services.range.lowerBound + 1)..<services.range.upperBound
        let serviceIndent = firstIndent(lines, in: childRange) ?? 2
        guard let serviceBlocks = blocks(lines, in: childRange, indent: serviceIndent) else {
            document.visualUnavailable = true; return document
        }
        for block in serviceBlocks {
            guard block.value.isEmpty || block.value == "{}", validName(block.key) else {
                document.visualUnavailable = true; return document
            }
            var service = DockerComposeService(name: block.key)
            let body = (block.range.lowerBound + 1)..<block.range.upperBound
            let indent = firstIndent(lines, in: body) ?? serviceIndent + 2
            guard let fields = blocks(lines, in: body, indent: indent) else {
                document.visualUnavailable = true; return document
            }
            for field in fields {
                let content = Array(lines[field.range.dropFirst()])
                switch field.key {
                case "image", "container_name", "restart", "command", "working_dir":
                    guard let value = scalar(field.value), content.allSatisfy({ clean($0).isEmpty }) else {
                        service.lockedFields.insert(field.key); continue
                    }
                    switch field.key {
                    case "image": service.image = value
                    case "container_name": service.containerName = value
                    case "restart": service.restart = value
                    case "command": service.command = value
                    default: service.workingDirectory = value
                    }
                case "build":
                    service.useBuild = true
                    if let value = scalar(field.value), !field.value.isEmpty { service.buildContext = value }
                    else if field.value.isEmpty,
                            let options = blocks(lines, in: bodyRange(field), indent: firstIndent(lines, in: bodyRange(field)) ?? indent + 2),
                            options.allSatisfy({ ["context", "dockerfile"].contains($0.key) && scalar($0.value) != nil && lines[$0.range.dropFirst()].allSatisfy { clean($0).isEmpty } }) {
                        service.buildContext = options.first { $0.key == "context" }.flatMap { scalar($0.value) } ?? "."
                        service.dockerfile = options.first { $0.key == "dockerfile" }.flatMap { scalar($0.value) } ?? "Dockerfile"
                    } else { service.lockedFields.insert("build") }
                case "ports":
                    if let values = list(field, lines: lines), values.allSatisfy({ parsePort($0) != nil }) {
                        service.ports = values.compactMap(parsePort)
                    } else { service.lockedFields.insert(field.key) }
                case "volumes":
                    if let values = list(field, lines: lines), values.allSatisfy({ parseVolume($0) != nil }) {
                        service.volumes = values.compactMap(parseVolume)
                    } else { service.lockedFields.insert(field.key) }
                case "env_file", "depends_on", "networks":
                    let values = field.key == "env_file" && !field.value.isEmpty ? scalar(field.value).map { [$0] } : list(field, lines: lines)
                    if let values {
                        switch field.key {
                        case "env_file": service.envFiles = values
                        case "depends_on": service.dependencies = values
                        default: service.networks = values
                        }
                    } else { service.lockedFields.insert(field.key) }
                case "environment":
                    if let values = list(field, lines: lines) {
                        service.environment = values.map { value in
                            let pair = value.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
                            return .init(key: pair[0], value: pair.count == 2 ? pair[1] : nil)
                        }
                    } else if field.value.isEmpty,
                              let values = blocks(lines, in: bodyRange(field), indent: firstIndent(lines, in: bodyRange(field)) ?? indent + 2),
                              values.allSatisfy({ scalar($0.value) != nil && lines[$0.range.dropFirst()].allSatisfy { clean($0).isEmpty } }) {
                        service.environment = values.map { .init(key: $0.key, value: $0.value.isEmpty || $0.value == "null" || $0.value == "~" ? nil : scalar($0.value)) }
                    } else { service.lockedFields.insert(field.key) }
                default: break
                }
            }
            document.services.append(service)
        }
        document.originalServices = document.services
        return document
    }

    static func serialize(_ document: DockerComposeDocument) throws -> String {
        if document.services == document.originalServices { return document.source }
        guard !document.visualUnavailable else { throw Failure(key: "docker.error.visualUnavailable") }
        let names = document.services.map(\.name)
        guard names.allSatisfy(validName), Set(names).count == names.count else { throw Failure(key: "docker.error.serviceName") }
        let lines = document.source.components(separatedBy: "\n")
        guard let roots = blocks(lines, in: lines.indices, indent: 0), let root = roots.first(where: { $0.key == "services" }) else { throw Failure(key: "docker.error.visualUnavailable") }
        let serviceRange = bodyRange(root)
        let serviceIndent = firstIndent(lines, in: serviceRange) ?? 2
        let originals = blocks(lines, in: serviceRange, indent: serviceIndent) ?? []
        var edits: [Edit] = []
        var additions: [String] = []
        for old in document.originalServices {
            guard let block = originals.first(where: { $0.key == old.name }) else { continue }
            guard let service = document.services.first(where: { $0.id == old.id }) else {
                edits.append(.init(range: block.range, lines: [])); continue
            }
            if service.name != old.name {
                edits.append(.init(range: block.range.lowerBound..<(block.range.lowerBound + 1), lines: [spaces(serviceIndent) + service.name + ":"]))
            }
            let indent = firstIndent(lines, in: bodyRange(block)) ?? serviceIndent + 2
            let fields = blocks(lines, in: bodyRange(block), indent: indent) ?? []
            let previous = renderedFields(old, indent: indent)
            let next = renderedFields(service, indent: indent)
            var appended: [String] = []
            for key in fieldOrder where previous[key] != next[key] {
                guard !old.lockedFields.contains(key) else { throw Failure(key: "docker.error.visualUnavailable") }
                let replacement = next[key] ?? []
                if let field = fields.first(where: { $0.key == key }) {
                    // Keep standalone comments even when replacing their adjacent value.
                    let comments = lines[field.range].filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
                    edits.append(.init(range: field.range, lines: comments + replacement))
                } else { appended += replacement }
            }
            if !appended.isEmpty {
                if block.value == "{}" {
                    edits.append(.init(range: block.range.lowerBound..<(block.range.lowerBound + 1), lines: [spaces(serviceIndent) + service.name + ":"]))
                }
                edits.append(.init(range: block.range.upperBound..<block.range.upperBound, lines: appended))
            }
        }
        for service in document.services where !document.originalServices.contains(where: { $0.id == service.id }) {
            additions.append(spaces(serviceIndent) + service.name + ":")
            let fields = renderedFields(service, indent: serviceIndent + 2)
            additions += fieldOrder.flatMap { fields[$0] ?? [] }
        }
        if !additions.isEmpty {
            if root.value == "{}" { edits.append(.init(range: root.range.lowerBound..<(root.range.lowerBound + 1), lines: ["services:"])) }
            edits.append(.init(range: root.range.upperBound..<root.range.upperBound, lines: additions))
        }
        // Only newly introduced volume references need declarations. Existing advanced declarations stay verbatim.
        let oldVolumes = Set(document.originalServices.flatMap(\.volumes).compactMap(\.namedVolume))
        let needed = Set(document.services.flatMap(\.volumes).compactMap(\.namedVolume)).subtracting(oldVolumes)
        if !needed.isEmpty {
            if let volumes = roots.first(where: { $0.key == "volumes" }) {
                guard volumes.value.isEmpty || volumes.value == "{}",
                      let entries = blocks(lines, in: bodyRange(volumes), indent: firstIndent(lines, in: bodyRange(volumes)) ?? 2) else {
                    throw Failure(key: "docker.error.volumeDeclaration")
                }
                let missing = needed.subtracting(entries.map(\.key)).sorted()
                if !missing.isEmpty {
                    if volumes.value == "{}" { edits.append(.init(range: volumes.range.lowerBound..<(volumes.range.lowerBound + 1), lines: ["volumes:"])) }
                    edits.append(.init(range: volumes.range.upperBound..<volumes.range.upperBound, lines: missing.map { "  \($0): {}" }))
                }
            } else { edits.append(.init(range: lines.count..<lines.count, lines: ["volumes:"] + needed.sorted().map { "  \($0): {}" })) }
        }
        // Several additions can share a boundary (last service, new services, top-level volumes).
        // Merge them before applying edits so fields never end up under the next service.
        var insertions: [Int: [String]] = [:]
        for edit in edits where edit.range.isEmpty { insertions[edit.range.lowerBound, default: []] += edit.lines }
        edits.removeAll { $0.range.isEmpty }
        edits += insertions.map { Edit(range: $0.key..<$0.key, lines: $0.value) }
        var output = lines
        // Insertions at a block boundary must be applied before a replacement ending there.
        for edit in edits.sorted(by: { ($0.range.lowerBound, $0.range.upperBound) > ($1.range.lowerBound, $1.range.upperBound) }) {
            output.replaceSubrange(edit.range, with: edit.lines)
        }
        return output.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
    }

    static func validName(_ name: String) -> Bool {
        name.range(of: "^[A-Za-z0-9][A-Za-z0-9_.-]*$", options: .regularExpression) != nil
    }
    private static let fieldOrder = ["image", "build", "container_name", "restart", "command", "working_dir", "ports", "environment", "env_file", "volumes", "depends_on", "networks"]
    private static func renderedFields(_ service: DockerComposeService, indent: Int) -> [String: [String]] {
        let pad = spaces(indent)
        var fields: [String: [String]] = [:]
        func value(_ key: String, _ text: String) { if !text.isEmpty { fields[key] = [pad + key + ": " + quote(text)] } }
        func array(_ key: String, _ values: [String]) { if !values.isEmpty { fields[key] = [pad + key + ":"] + values.map { pad + "  - " + quote($0) } } }
        if service.useBuild {
            fields["build"] = [pad + "build:", pad + "  context: " + quote(service.buildContext), pad + "  dockerfile: " + quote(service.dockerfile)]
        } else { value("image", service.image) }
        value("container_name", service.containerName); value("restart", service.restart)
        value("command", service.command); value("working_dir", service.workingDirectory)
        array("ports", service.ports.map(\.yaml)); array("env_file", service.envFiles)
        array("volumes", service.volumes.map(\.yaml)); array("depends_on", service.dependencies); array("networks", service.networks)
        if !service.environment.isEmpty {
            let rows: [String] = service.environment.map { variable in
                let value = variable.value.map { " " + quote($0) } ?? ""
                return pad + "  " + quote(variable.key) + ":" + value
            }
            fields["environment"] = [pad + "environment:"] + rows
        }
        return fields
    }
    private static func spaces(_ count: Int) -> String { String(repeating: " ", count: count) }
    private static func quote(_ value: String) -> String {
        // JSON string literals are valid YAML double-quoted scalars, including control escapes.
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        return String(data: try! encoder.encode(value), encoding: .utf8)!
    }
    private static func bodyRange(_ block: Block) -> Range<Int> { (block.range.lowerBound + 1)..<block.range.upperBound }
    private static func firstIndent(_ lines: [String], in range: Range<Int>) -> Int? {
        range.first(where: { !clean(lines[$0]).isEmpty }).map { lines[$0].prefix(while: { $0 == " " }).count }
    }
    private static func blocks(_ lines: [String], in range: Range<Int>, indent: Int) -> [Block]? {
        var starts: [(Int, String, String)] = []
        for index in range {
            let text = clean(lines[index])
            if text.isEmpty { continue }
            let level = lines[index].prefix(while: { $0 == " " }).count
            guard level >= indent else { return nil }
            if level != indent { continue }
            guard let pair = mapping(text), !starts.contains(where: { $0.1 == pair.0 }) else { return nil }
            starts.append((index, pair.0, pair.1))
        }
        return starts.enumerated().map { offset, row in
            Block(key: row.1, value: row.2, range: row.0..<(offset + 1 < starts.count ? starts[offset + 1].0 : range.upperBound), indent: indent)
        }
    }
    private static func mapping(_ text: String) -> (String, String)? {
        var quote: Character?
        var escaped = false
        for index in text.indices {
            let character = text[index]
            if escaped { escaped = false; continue }
            if character == "\\", quote == "\"" { escaped = true; continue }
            if let current = quote { if character == current { quote = nil }; continue }
            if character == "\"" || character == "'" { quote = character; continue }
            if character == ":" {
                let after = text.index(after: index)
                guard after == text.endIndex || text[after].isWhitespace else { continue }
                guard let key = scalar(String(text[..<index])), !key.isEmpty else { return nil }
                return (key, String(text[after...]).trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }
    private static func clean(_ line: String) -> String {
        var quote: Character?
        var escaped = false
        for index in line.indices {
            let character = line[index]
            if escaped { escaped = false; continue }
            if character == "\\", quote == "\"" { escaped = true; continue }
            if let current = quote { if character == current { quote = nil }; continue }
            if character == "\"" || character == "'" { quote = character; continue }
            if character == "#", index == line.startIndex || line[line.index(before: index)].isWhitespace {
                return line[..<index].trimmingCharacters(in: .whitespaces)
            }
        }
        return line.trimmingCharacters(in: .whitespaces)
    }
    private static func scalar(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("\"") { return try? JSONDecoder().decode(String.self, from: Data(value.utf8)) }
        if value.hasPrefix("'") {
            guard value.count >= 2, value.hasSuffix("'") else { return nil }
            return String(value.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
        }
        guard !value.contains("\n"), !value.contains(": "), !["[", "{", "|", ">", "&", "*", "!", "%", "@", "`"].contains(where: { value.hasPrefix($0) }) else { return nil }
        return value
    }
    private static func list(_ block: Block, lines: [String]) -> [String]? {
        if block.value == "[]" { return [] }
        guard block.value.isEmpty else { return nil }
        let rows = lines[bodyRange(block)].filter { !clean($0).isEmpty }
        guard let first = rows.first else { return [] }
        let indent = first.prefix(while: { $0 == " " }).count
        var values: [String] = []
        for row in rows {
            let text = clean(row)
            guard row.prefix(while: { $0 == " " }).count == indent, text.hasPrefix("- "), let value = scalar(String(text.dropFirst(2))) else { return nil }
            values.append(value)
        }
        return values
    }
    private static func parsePort(_ value: String) -> ComposePortMapping? {
        // Preserve interpolation, ranges and IPv6 in YAML instead of splitting their colons.
        guard !value.contains("$"), !value.contains("["), !value.contains("-") else { return nil }
        let parts = value.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard parts.count <= 2, parts.count == 1 || ["tcp", "udp"].contains(parts[1]) else { return nil }
        let ports = parts[0].split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard (1...3).contains(ports.count), let target = ports.last, let port = Int(target), (1...65535).contains(port) else { return nil }
        if ports.count > 1 { guard let host = Int(ports[ports.count - 2]), (1...65535).contains(host) else { return nil } }
        return .init(host: ports.count > 1 ? ports[ports.count - 2] : "", target: target, transport: parts.count == 2 ? parts[1] : "tcp", hostIP: ports.count == 3 ? ports[0] : "")
    }
    private static func parseVolume(_ value: String) -> ComposeVolumeMount? {
        guard !value.contains("$") else { return nil }
        let parts = value.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard (1...3).contains(parts.count), parts.count < 3 || ["rw", "ro"].contains(parts[2]) else { return nil }
        return .init(source: parts.count > 1 ? parts[0] : "", target: parts.count > 1 ? parts[1] : parts[0], readOnly: parts.count == 3 && parts[2] == "ro")
    }
}
