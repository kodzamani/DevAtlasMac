// Run from the repository root:
// swiftc -parse-as-library DevAtlasMac/Models/UnusedCodeResult.swift DevAtlasMac/Enums/AnalyzerError.swift \
//   DevAtlasMac/Services/UnusedCodeAnalyzer/LanguageAnalyzer.swift \
//   DevAtlasMac/Services/UnusedCodeAnalyzer/Languages/SwiftAnalyzer.swift \
//   DevAtlasMac/Services/UnusedCodeAnalyzer/Languages/Swift/*.swift \
//   Tests/SwiftUnusedCodeAnalyzerTests.swift -o /tmp/devatlas-swift-unused-tests && /tmp/devatlas-swift-unused-tests
import Foundation

@main
struct SwiftUnusedCodeAnalyzerTests {
    static let fileManager = FileManager.default

    static func main() throws {
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("DevAtlas swift unused \(UUID().uuidString)", isDirectory: true)
            .resolvingSymlinksInPath()
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        try checkLexer()
        try checkProject(in: root)
        print("SwiftAnalyzer: all checks passed (lexer, declarations, retention rules, self references, resources).")
    }

    // MARK: - Lexer

    private static func checkLexer() throws {
        let source = ##"""
        // comment mentions hiddenA
        /* block /* nested */ hiddenB */
        let x = "literal hiddenC \(visibleA) more"
        let y = #"raw \(hiddenD) \#(visibleB)"#
        let z = """
            multi hiddenE \(visibleC)
            """
        #if DEBUG_FLAG
        let w = $visibleD + `default`
        #endif
        """##
        let names = Set(SwiftSourceLexer.tokenize(source).filter { $0.kind == .identifier }.map(\.text))
        for hidden in ["hiddenA", "hiddenB", "hiddenC", "hiddenD", "hiddenE", "DEBUG_FLAG"] {
            try expect(!names.contains(hidden), "lexer should drop \(hidden)")
        }
        for visible in ["visibleA", "visibleB", "visibleC", "visibleD", "default"] {
            try expect(names.contains(visible), "lexer should keep \(visible)")
        }
    }

    // MARK: - Project

    private static func checkProject(in root: URL) throws {
        try write("""
        import SwiftUI

        @main
        struct DemoApp: App {
            var body: some Scene { WindowGroup { ContentView() } }
        }

        struct ContentView: View {
            @State private var count = 0
            private var unusedPrivateView: some View { Text("x") }
            var internalHelperOnView: Int { 1 }

            var body: some View {
                Text("\\(count) \\(Formatter.shared.format(count))")
                    .onAppear { _count.wrappedValue = Mode.fast.rawValue.count }
            }
        }

        struct UnusedView: View {
            var body: some View { Text("never shown") }
        }
        """, to: root, "App/ContentView.swift")

        try write("""
        import Foundation

        final class Formatter {
            static let shared = Formatter()
            func format(_ value: Int) -> String { String(value) }
            func neverCalled() {}
            private func privateNeverCalled() {}
            class func classMethodNeverCalled() {}
        }

        final class SelfReferencingOnly {
            static let instance = SelfReferencingOnly()
        }

        extension SelfReferencingOnly {
            func copy() -> SelfReferencingOnly { self }
        }

        enum Mode: String {
            case fast, slow
        }

        enum State {
            case idle
            case loading(progress: Double)
            case unusedCase
        }

        let currentState: State = .loading(progress: 0)
        _ = State.idle

        struct Payload: Codable {
            let storedButUnread: String
            func unusedPayloadMethod() {}
            enum CodingKeys: String, CodingKey { case storedButUnread = "stored" }
        }

        protocol Greeter {
            func greet()
        }

        struct EnglishGreeter: Greeter {
            func greet() {}
            func unusedGreeterHelper() {}
        }

        let greeter: Greeter = EnglishGreeter()

        class Base {
            func hook() {}
        }

        class Derived: Base {
            override func hook() {}
            @objc func objcExposed() {}
            @IBAction func tapped(_ sender: Any) {}
        }

        let derived: Base = Derived()

        class StoryboardController {}
        private(set) var setterRestricted = 0
        """, to: root, "App/Services.swift")

        try write("""
        <document><scenes><viewController customClass="StoryboardController"/></scenes></document>
        """, to: root, "App/Main.storyboard")

        try write("""
        import XCTest
        final class ServiceTests: XCTestCase {
            func testSomething() { Formatter.classMethodNeverCalled() }
            func unusedTestHelper() {}
        }
        """, to: root, "AppTests/ServiceTests.swift")

        try write("swift junk", to: root, ".build/checkouts/Dep/Sources/Dep.swift")

        let results = try SwiftAnalyzer().analyze(projectPath: root.path)
        let reported = Set(results.map(\.name))

        let expectedUnused: [String] = [
            "UnusedView", "unusedPrivateView", "neverCalled", "privateNeverCalled",
            "SelfReferencingOnly", "unusedCase", "unusedPayloadMethod", "unusedGreeterHelper",
            "setterRestricted", "Payload", "currentState", "greeter", "derived"
        ]
        for name in expectedUnused {
            try expect(reported.contains(name), "\(name) should be reported as unused. Got: \(reported.sorted())")
        }

        let expectedRetained: [String] = [
            "DemoApp", "ContentView", "body", "count", "Formatter", "shared", "format",
            "Mode", "fast", "slow", "State", "idle", "loading", "storedButUnread", "CodingKeys",
            "Greeter", "greet", "EnglishGreeter", "Base", "Derived", "objcExposed", "tapped",
            "StoryboardController", "internalHelperOnView", "classMethodNeverCalled",
            "unusedTestHelper", "Dep"
        ]
        for name in expectedRetained {
            try expect(!reported.contains(name), "\(name) should not be reported")
        }

        // `Base.hook()` is never called; its `override` in `Derived` is retained.
        let hooks = results.filter { $0.name == "hook" }
        try expect(hooks.count == 1 && hooks[0].location.hasSuffix(":50:10"),
                   "only Base.hook should be reported, got \(hooks.map(\.location))")

        let neverCalled = try unwrap(results.first { $0.name == "neverCalled" }, "neverCalled result")
        try expect(neverCalled.kind == "function", "neverCalled kind should be function, got \(neverCalled.kind)")
        try expect(neverCalled.location == "App/Services.swift:6:10",
                   "neverCalled location should be App/Services.swift:6:10, got \(neverCalled.location)")
        let unusedCase = try unwrap(results.first { $0.name == "unusedCase" }, "unusedCase result")
        try expect(unusedCase.kind == "enum case", "unusedCase kind should be enum case")
    }

    // MARK: - Helpers

    private static func write(_ contents: String, to root: URL, _ relativePath: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw TestFailure(message: message) }
    }

    private static func unwrap<T>(_ value: T?, _ label: String) throws -> T {
        guard let value else { throw TestFailure(message: "missing \(label)") }
        return value
    }

    struct TestFailure: Error, CustomStringConvertible {
        let message: String
        var description: String { "FAILED: \(message)" }
    }
}
