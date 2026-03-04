import SwiftUI

struct AIPromptsContentView: View {
    private let promptGridColumns = [
        GridItem(.flexible(), spacing: 20, alignment: .top),
        GridItem(.flexible(), spacing: 20, alignment: .top)
    ]
    
    // MARK: - Prompt Categories
    
    private let promptCategories: [(title: String, icon: String, prompts: [(title: String, description: String, prompt: String)])] = [
        
        // ────────────────────────────────────────
        // MARK: 1 · Kod Kalitesi
        // ────────────────────────────────────────
        (
            title: "aiprompts.category.codeQuality".localized,
            icon: "checkmark.shield",
            prompts: [
                (
                    title: "aiprompts.prompt.unusedCode.title".localized,
                    description: "aiprompts.prompt.unusedCode.desc".localized,
                    prompt: """
You are an expert static-analysis engineer. Perform a comprehensive dead-code audit on my project.

## What to scan
1. **Unused functions / methods** – declared but never called anywhere in the codebase.
2. **Unused variables & constants** – assigned but never read.
3. **Unused classes, structs, enums & protocols** – defined but never instantiated or conformed to.
4. **Unused imports / dependencies** – `import` statements whose symbols are never referenced in the file.
5. **Dead code paths** – branches that can never execute (e.g., `if false`, unreachable code after `return`/`throw`).
6. **Orphan files** – source files that aren't compiled or referenced by any target.

## Analysis rules
- Cross-reference every declaration against the *entire* project (not just the declaring file).
- Consider dynamic dispatch, reflection, serialization frameworks, dependency injection containers, and configuration files before flagging something as unused.
- Respect access control: `public`/`exported` APIs in library targets may be intentionally exposed.
- Account for language-specific indirection: annotations, attributes, decorators, runtime reflection, event systems.

## Output format (for every finding)
| # | File path | Line(s) | Symbol name | Kind | Confidence | Suggested action |
|---|-----------|---------|-------------|------|------------|-----------------|

- **Confidence**: High / Medium / Low
- **Suggested action**: Delete, Replace with `_`, Move to extension, etc.

After the table, provide a **Summary** with total counts per kind and an estimated LOC reduction.
"""
                ),
                (
                    title: "aiprompts.prompt.codeSmells.title".localized,
                    description: "aiprompts.prompt.codeSmells.desc".localized,
                    prompt: """
You are a senior code-quality consultant. Perform a thorough code-smell and anti-pattern review on my project.

## Smell categories to check

### Bloaters
- **Long Method**: Functions > 30 lines. Suggest extraction points.
- **Large Class / God Object**: Classes > 300 lines or with > 7 responsibilities.
- **Long Parameter List**: Functions with > 4 parameters. Suggest parameter objects.
- **Primitive Obsession**: Strings/ints used where a value type (enum, struct) is appropriate.

### Object-Orientation Abusers
- **Switch Statements**: Repeated switch/case on the same type — suggest polymorphism.
- **Refused Bequest**: Subclasses that ignore most of the parent's interface.
- **Temporary Field**: Properties only set in certain code paths.

### Change Preventers
- **Divergent Change**: One class modified for many unrelated reasons.
- **Shotgun Surgery**: One change requires edits across many classes.
- **Parallel Inheritance**: Adding a subclass in one hierarchy forces a subclass in another.

### Dispensables
- **Duplicate Code**: Blocks ≥ 6 lines appearing in 2+ places. Show the duplicated snippet.
- **Dead Code**: (Cross-reference with unused-code check.)
- **Speculative Generality**: Abstractions created "just in case" but never used.
- **Magic Numbers / Strings**: Literal values without named constants.

### Couplers
- **Feature Envy**: Methods that use another object's data more than their own.
- **Inappropriate Intimacy**: Classes accessing each other's private internals.
- **Message Chains**: `a.b.c.d.e` — suggest Law of Demeter fixes.

## Output format
For each smell found:
```
### [Smell Name] — `FileName:L42`
**Severity**: 🔴 High | 🟡 Medium | 🟢 Low
**Description**: …
**Before** (code snippet)
**After** (refactored code snippet)
```

End with a prioritized action plan (top‑5 highest-impact refactors).
"""
                ),
                (
                    title: "aiprompts.prompt.memoryLeaks.title".localized,
                    description: "aiprompts.prompt.memoryLeaks.desc".localized,
                    prompt: """
You are an expert memory management engineer. Audit my project for every class of memory issue regardless of language or platform.

## 1 · Reference / Ownership Cycles
- Objects holding strong/owning references to each other creating circular chains that prevent deallocation.
- Closures / lambdas capturing outer scope objects strongly when a weak/unowned reference would suffice.
- Parent ↔ Child strong references where the child should hold only a weak back-reference.
- Observer / listener registrations that keep objects alive longer than intended.

## 2 · Leaked Resources
- Event listeners, observers, or pub-sub subscriptions registered but never removed.
- Timers, intervals, or scheduled callbacks never cancelled/invalidated.
- Network or I/O tasks not cancelled when the owning object is destroyed.
- File handles, streams, database connections, or sockets opened but never closed in error paths.
- Native handles or OS resources acquired without a guaranteed release path.

## 3 · Unbounded Growth
- In-memory caches with no size limit or eviction policy.
- Collections that grow monotonically (items appended, never removed).
- Event history, log buffers, or undo stacks with no max size.
- Repeated object creation inside loops without reuse or pooling.

## 4 · Singleton & Global State
- Singletons holding strong references to large or short-lived objects.
- Static/global caches that survive the lifetime they should be scoped to.
- Module-level state that accumulates data across requests/sessions.

## 5 · Framework/Language-Specific Patterns
- Identify any language-specific memory pitfalls present (e.g., retain cycles in reference-counted languages, finalizer reliance in GC languages, manual free omissions in C/C++, Go goroutine leaks, etc.).
- Flag incorrect use of weak/soft/phantom references where present.

## For every finding provide:
1. **File & line number**
2. **Risk level**: 🔴 Critical (guaranteed leak) | 🟡 Likely (leak under certain paths) | 🟢 Potential (edge-case leak)
3. **Explanation** of how the cycle/leak forms
4. **Fix** — complete code snippet showing the corrected version
5. **Verification tip** — how to confirm the leak using available profiling tools (memory profiler, heap snapshot, valgrind, etc.)

End with a **Memory Health Score** (A–F) and a top-3 priority fix list.
"""
                ),
                (
                    title: "aiprompts.prompt.securityAudit.title".localized,
                    description: "aiprompts.prompt.securityAudit.desc".localized,
                    prompt: """
You are an application-security specialist performing a white-box security audit. Analyze my project for every category below regardless of language or platform.

## 1 · Secrets & Credentials
- Hardcoded API keys, tokens, passwords, certificates, or private keys in source code.
- Secrets in configuration files, manifests, or environment files committed to VCS.
- Credentials written to logs, console output, or error messages.
- Secrets embedded in build artifacts, comments, or test fixtures.

## 2 · Sensitive Data Storage
- Sensitive data stored in plain-text files, unsecured databases, or low-security storage (cookies, localStorage, shared preferences, UserDefaults).
- Sensitive data not encrypted at rest.
- Sensitive information exposed in application logs, stack traces, or crash reports.
- Temporary files containing sensitive data not securely deleted.

## 3 · Network Security
- HTTP (non-TLS) connections or disabled certificate validation.
- Certificate pinning absent on critical endpoints.
- SSL/TLS configuration weaknesses (outdated protocol versions, weak cipher suites).
- API responses containing sensitive data not marked `no-store` or `no-cache`.
- Missing CORS restrictions or overly permissive CORS policies.

## 4 · Input Validation
- User input passed to shell commands, OS processes, or eval-type functions (command/code injection).
- SQL injection via string interpolation in database queries — use parameterized queries.
- Path traversal: user-supplied paths not sanitized or sandboxed.
- Unvalidated redirects and forwards.
- XML/JSON deserialization of untrusted input without schema validation.
- Format string vulnerabilities.

## 5 · Authentication & Authorization
- Missing or bypassable authentication checks.
- Insecure session token storage or transmission.
- Missing token expiry or refresh handling.
- Broken object-level authorization (accessing other users' resources).
- Privilege escalation paths.

## 6 · Dependency Security
- Known CVEs in current dependency versions.
- Packages with no active security maintenance.
- Overly permissive version ranges allowing supply-chain attacks.
- Transitive dependencies not audited.

## Output format per finding
| Severity | CWE ID | Location | Description | Remediation |
|----------|--------|----------|-------------|-------------|
| 🔴 Critical / 🟡 High / 🟢 Medium / ⚪ Low | CWE-xxx | file:line | … | Code fix |

End with an **Executive Summary**: total findings per severity, top-3 immediate actions, and an overall risk rating (Critical/High/Medium/Low).
"""
                ),
                (
                    title: "aiprompts.prompt.errorHandling.title".localized,
                    description: "aiprompts.prompt.errorHandling.desc".localized,
                    prompt: """
You are a reliability engineer. Audit my project for error-handling weaknesses that could lead to crashes, panics, or silent failures — regardless of language or platform.

## What to check

### Unsafe / Unchecked Operations
- Forced/unsafe type casts, coercions, or assertions without validation.
- Array / collection index access without bounds checking.
- Pointer arithmetic or unsafe memory access without guards.
- Integer overflow / underflow in arithmetic operations.
- Division by zero potential.
- Null/nil/undefined dereferences without prior checks.

### Missing Error Propagation
- Empty catch/except blocks that silently swallow errors.
- Discarded error return values (ignored Result, errno, error codes).
- Functions that return null/nil/undefined instead of propagating exceptions or errors.
- Callbacks or promise rejections left unhandled.
- Fire-and-forget async operations without error handling.

### Defensive Programming
- Missing boundary checks on external/user-provided input.
- Unhandled switch/match/enum cases (missing default or exhaustive handling).
- Missing validation before parsing or deserializing external data (JSON, XML, etc.).
- Assumptions about collection being non-empty before accessing first/last element.
- Race conditions on shared mutable state without synchronization.

### Async & Concurrent Error Handling
- Async tasks / coroutines / goroutines / promises without error handling.
- Missing timeout handling on network or I/O operations.
- Cancellation not propagated through async call chains.
- Errors lost in concurrent task coordination.

### User-Facing Error Experience
- Generic error messages ("Something went wrong") that don't help the user.
- Error messages not localized when the application is multi-language.
- Missing retry mechanisms for recoverable errors (e.g., network timeouts).
- No offline / connectivity-unavailable handling.
- Missing loading/error/empty states in UI flows.

## Output format per finding
```
📍 File:Line — [Severity 🔴🟡🟢]
Issue: …
Current code: `snippet`
Fixed code: `snippet`
Rationale: Why this matters in production
```

End with a **Crash Risk Score** (1–10) and top-5 fixes to eliminate the highest-impact crash risks.
"""
                )
            ]
        ),
        
        // ────────────────────────────────────────
        // MARK: 2 · Performans
        // ────────────────────────────────────────
        (
            title: "aiprompts.category.performance".localized,
            icon: "speedometer",
            prompts: [
                (
                    title: "aiprompts.prompt.bottleneck.title".localized,
                    description: "aiprompts.prompt.bottleneck.desc".localized,
                    prompt: """
You are a performance-engineering specialist. Perform a holistic performance audit on my project.

## Computational Complexity
- Identify every nested loop and estimate Big-O complexity. Flag anything ≥ O(n²) operating on collections that could grow beyond 100 items.
- Find recursive functions missing memoization or tail-call optimization.
- Spot unnecessary repeated computations (same expensive call in a loop without caching the result).
- String concatenation in loops (suggest using array + `joined()`).

## Main Thread Blocking
- File I/O operations (read/write/delete) on the main thread.
- JSON parsing / codable decoding on the main thread with data > 1 KB.
- Image processing (resize, filter) on the main thread.
- Synchronous network calls or synchronous disk access.
- Heavy utility object creation (formatters, parsers, converters) inside tight loops or per-item rendering calls — suggest caching or reuse.

## Memory & Allocation
- Large objects copied where they should be referenced (or vice versa).
- Repeated small allocations in tight loops — suggest pre-allocation or object pooling.
- Image loading without downsampling (loading full-resolution images for small thumbnails).
- Caches without size limits — potential memory pressure.

## Concurrency Issues
- Excessive thread/coroutine context switching.
- Thread starvation — blocking on synchronization primitives from critical threads.
- Data races — mutable shared state without proper synchronization.
- Unspecified priority / QoS on background work competing with foreground work.

## I/O & Networking
- Redundant API calls (same data fetched multiple times).
- Missing response caching / ETag support.
- Large payload downloads without pagination.
- Missing request deduplication (same URL requested concurrently by multiple callers).

## Output format per finding
| File:Line | Category | Impact (🔴 High, 🟡 Med, 🟢 Low) | Current | Optimized | Expected Speedup |
|-----------|----------|------|---------|-----------|-----------------|

End with a **Performance Score** (A–F), a flame-graph-style text diagram showing the top-5 hot paths, and a prioritized optimization roadmap.
"""
                ),
                (
                    title: "aiprompts.prompt.swiftuiRender.title".localized,
                    description: "aiprompts.prompt.swiftuiRender.desc".localized,
                    prompt: """
You are a UI rendering performance expert. Audit every view and component in my project for rendering efficiency, regardless of the UI framework used (React, SwiftUI, Flutter, Angular, Vue, Jetpack Compose, etc.).

## State Management
- **Overly broad state**: A single state object change triggering re-renders of large, unrelated sub-trees. Suggest splitting state into smaller, focused pieces.
- **Wrong ownership level**: State managed at a higher level than necessary, causing cascading re-renders down the tree.
- **Derived state not memoized**: Computed/derived values recalculated on every render. Suggest memoization or selectors.
- **Object identity instability**: New object/array references created on every render even when data hasn't changed, breaking equality checks.

## Component / View Body Optimization
- **Heavy computation on render**: Sorting, filtering, date formatting, or expensive transforms executed inline during render — suggest memoization, caching, or moving to a side effect.
- **Oversized components**: Components > 50 lines of template/body — suggest extracting sub-components.
- **Missing equality checks**: Components without proper equality/memo boundaries that re-render on every parent update.
- **Unstable keys/IDs**: List items keyed by index or unstable values causing full re-mounts on every data update.

## List & Collection Performance
- **Non-virtualized large lists**: Rendering all items in a large collection (> 20 items) without virtualization/lazy rendering.
- **Missing stable item identifiers**: Causing unnecessary diff/reconciliation work.
- **Per-item data fetching in lists**: N individual fetches instead of batch loading.

## Animation & Visual
- **Animations triggering layout**: Animating properties that force full layout recalculations.
- **Expensive visual effects** (shadows, blurs) without GPU compositing hints or layer isolation.
- **Layout thrashing**: Interleaving read and write operations on layout properties.

## Asset & Media
- **Oversized images**: Loading full-resolution images for small display sizes — suggest on-demand resizing or responsive images.
- **Missing caching**: Remote images or assets re-fetched on every render cycle.
- **Missing placeholder/skeleton**: No loading state, causing layout shifts.

## For every finding provide:
```
### [Issue] — `FileName:L42`
**Impact**: How many unnecessary renders per second this likely causes
**Before**: (code)
**After**: (optimized code)
**Why it works**: 1-2 sentence explanation of the rendering model detail
```

End with a **Render Efficiency Score** (A–F) and a top-5 quick-win list sorted by user-visible impact.
"""
                ),
                (
                    title: "aiprompts.prompt.appLaunch.title".localized,
                    description: "aiprompts.prompt.appLaunch.desc".localized,
                    prompt: """
You are an application startup performance specialist. Analyze my project to minimize time-to-interactive — applicable to any language or platform (mobile, web, desktop, server).

## Initialization & Bootstrap Phase
- List everything that executes at program startup / module load / app entry point.
- Flag synchronous work that could be deferred: database migrations, config parsing, heavy object initialization, SDK/library initialization.
- Identify global/static initializers that run before main logic.
- Unused libraries or modules still loaded at startup — suggest lazy loading or removal.

## Main Entry Point
- What happens in the main function / entry point / app initialization method?
- Flag blocking operations: file reads, network calls, cryptographic operations, large data parsing.
- Third-party SDK initializations that could be deferred or moved to background threads.
- Suggest a startup sequence: critical-path-only → first-frame → idle initialization.

## First Visible Screen / Response
- What is the first visible screen or first HTTP response? Is its data available synchronously?
- Are there blocking data loads preventing the first paint/render?
- Suggest skeleton/shimmer/streaming patterns for perceived performance.
- For servers: time to first byte (TTFB), cold start optimizations.

## Warm Start & Subsequent Launches
- Is state/session restoration implemented efficiently (no redundant re-fetching)?
- Are frequently accessed data sources cached between sessions?
- Background task prioritization — unnecessary work on resume?

## Specific Recommendations
For each item found, provide:
1. **What** is happening
2. **When** it happens (process start, entry point, first render, post-first-render)
3. **Duration estimate** (ms)
4. **Fix**: Code showing how to defer, lazy-load, or eliminate the work
5. **Measurement**: How to verify the improvement using available profiling tools (Chrome DevTools, Instruments, perf, async-profiler, etc.)

End with a **Startup Timeline Diagram** (text-based Gantt chart) showing current vs. optimized sequence, and estimated total time saved.
"""
                )
            ]
        ),
        
        // ────────────────────────────────────────
        // MARK: 3 · Mimari & Tasarım
        // ────────────────────────────────────────
        (
            title: "aiprompts.category.architecture".localized,
            icon: "building.2",
            prompts: [
                (
                    title: "aiprompts.prompt.architectureDeep.title".localized,
                    description: "aiprompts.prompt.architectureDeep.desc".localized,
                    prompt: """
You are a principal software architect. Perform a comprehensive architecture review of my project.

## SOLID Principles Compliance
For each principle, evaluate compliance and give specific violations:

**S — Single Responsibility**
- List every class/struct with > 2 distinct responsibilities.
- For each, suggest how to split (e.g., "Extract networking into `APIService`, keep UI logic in ViewModel").

**O — Open/Closed**
- Places where adding a new feature requires modifying existing classes instead of extending.
- Suggest protocol + extension patterns to make it extensible.

**L — Liskov Substitution**
- Subclasses that violate the contract of their parent.
- Protocol conformances that only partially implement the expected behavior.

**I — Interface Segregation**
- Protocols with > 5 methods where most conformers only use 2-3.
- Suggest splitting into focused protocols.

**D — Dependency Inversion**
- Concrete type dependencies instead of protocol-based abstractions.
- View models directly creating services instead of receiving them via injection.

## Dependency Graph Analysis
- Draw a text-based dependency graph of the main modules/layers.
- Identify circular dependencies.
- Identify layers that skip intermediate layers (e.g., View directly accessing Repository).
- Suggest proper layer boundaries.

## Module Boundaries
- Are features properly isolated? Could one feature be removed without breaking others?
- Suggest a module structure for SPM/framework-based modularization.
- Identify shared code that should become a core/common module.

## Data Flow Architecture
- Map how data flows from API/Database → Model → ViewModel → View.
- Identify places where this flow is violated (e.g., View directly calling API).
- Suggest reactive data flow improvements (reactive streams, async/await, Rx-style patterns, or event-driven architectures).

## Testability Assessment
- Can each layer be tested in isolation?
- Are dependencies mockable?
- Rate overall testability: A–F.

## Output
Provide an **Architecture Report Card**:
| Principle/Area | Grade (A–F) | Key Issue | Top Fix |
|---------------|-------------|-----------|---------|

Then provide a **Refactoring Roadmap** with 3 phases: Quick Wins (< 1 day), Medium Effort (1-3 days), Strategic (1-2 weeks).
"""
                ),
                (
                    title: "aiprompts.prompt.designPatterns.title".localized,
                    description: "aiprompts.prompt.designPatterns.desc".localized,
                    prompt: """
You are a design-patterns expert. Analyze my codebase for pattern usage, misuse, and opportunities.

## Currently Used Patterns — Audit Each
For every design pattern you detect in the code:
1. Name the pattern and where it's used (file, class).
2. Grade the implementation: ✅ Correct, ⚠️ Partial, ❌ Incorrect.
3. If incorrect, show how to fix it with code.

## Missing Patterns — Suggest Where They Apply

**Creational**
- **Factory Method / Abstract Factory**: Are objects created with complex conditional logic? Suggest factory.
- **Builder**: Are there initializers with > 5 parameters? Suggest builder pattern.
- **Dependency Injection**: Are dependencies created inline? Suggest DI container or manual injection.

**Structural**
- **Adapter**: Are there awkward type conversions between layers? Suggest adapters.
- **Decorator**: Is behavior added via subclassing where composition would be better?
- **Facade**: Are clients calling many fine-grained APIs? Suggest a facade.
- **Coordinator**: Is navigation logic scattered in views? Suggest coordinator pattern.

**Behavioral**
- **Strategy**: Are there if/else or switch chains selecting algorithms? Suggest strategy.
- **Observer**: Are there manual callback chains? Suggest pub-sub / observer patterns (event emitters, reactive streams, delegates, signals).
- **Command**: Are there undoable operations without a command pattern?
- **State Machine**: Are there boolean flags tracking states? Suggest a proper state machine.
- **Repository**: Is data access mixed with business logic? Suggest repository pattern.

## Anti-Patterns Detected
- **Massive View Controller / View Model**: Doing everything in one place.
- **Singleton Abuse**: Singletons used as global mutable state.
- **God Object**: One class knowing everything.
- **Lava Flow**: Dead code and experimental code left in production.
- **Golden Hammer**: Using the same solution for every problem.

## For each suggestion, provide:
1. The specific file(s) and code area
2. **Current code** snippet (problematic)
3. **Proposed code** snippet (with pattern applied)
4. **Benefit**: Why this pattern improves the codebase (testability, flexibility, readability)

End with a **Pattern Adoption Priority Matrix** (Impact vs Effort grid) for the top-10 suggestions.
"""
                ),
                (
                    title: "aiprompts.prompt.refactoringGuide.title".localized,
                    description: "aiprompts.prompt.refactoringGuide.desc".localized,
                    prompt: """
You are a refactoring consultant following Martin Fowler's refactoring catalog. Identify every refactoring opportunity in my project.

## Scanning Criteria

### Method-Level Refactoring
- **Extract Method**: Function blocks > 20 lines with a clear sub-purpose. Show extraction.
- **Inline Method**: Trivial one-line methods that just delegate. Suggest inlining.
- **Replace Temp with Query**: Temporary variables that could be computed properties.
- **Introduce Parameter Object**: Methods with > 3 related parameters. Create a struct.
- **Replace Conditional with Polymorphism**: if/switch chains on type. Use protocol + conformances.
- **Decompose Conditional**: Complex boolean expressions. Extract into named methods.

### Class-Level Refactoring
- **Extract Class**: Classes with > 5 properties or > 8 methods covering 2+ responsibilities.
- **Inline Class**: Classes with only 1 method that could merge into caller.
- **Replace Inheritance with Composition**: Deep hierarchies (> 3 levels). Use protocol + delegation.
- **Introduce Extension**: Utility methods on types that belong in an extension.

### Data Organization
- **Replace Magic Number with Constant**: Every literal value that should be named.
- **Encapsulate Field**: Public `var` properties that should use getters/setters.
- **Replace Array with Object**: Arrays/tuples used with index-based access where a struct fits better.

### Architecture-Level Refactoring
- **Move Method/Property**: Methods that use another class's data more than their own.
- **Extract Protocol**: Concrete dependencies that should be abstracted.
- **Introduce Service Layer**: Business logic in views/view models that should be in a service.

## For each refactoring opportunity, provide:
```
## [Refactoring Name] — `File:L42-L78`
**Fowler Catalog Reference**: Chapter/page
**Risk**: 🔴 High (behavior change possible) | 🟡 Medium | 🟢 Low (safe)
**Effort**: ⏱ Small (< 30 min) | ⏱⏱ Medium (1-3 hrs) | ⏱⏱⏱ Large (> 3 hrs)

### Before
```swift
// current code
```

### After
```swift
// refactored code
```

### Step-by-step
1. First, ...
2. Then, ...
3. Finally, verify by ...
```

End with a **Refactoring Backlog** table sorted by (Risk ASC, Impact DESC) with estimated total effort.
"""
                )
            ]
        ),
        
        // ────────────────────────────────────────
        // MARK: 4 · Testing
        // ────────────────────────────────────────
        (
            title: "aiprompts.category.testing".localized,
            icon: "testtube.2",
            prompts: [
                (
                    title: "aiprompts.prompt.testCoverage.title".localized,
                    description: "aiprompts.prompt.testCoverage.desc".localized,
                    prompt: """
You are a QA architect. Perform a comprehensive test gap analysis on my project regardless of the language or testing framework used.

## Coverage Analysis
For each source file, determine:
1. Whether a corresponding test file exists.
2. Which public methods/functions have tests and which don't.
3. Which code paths (branches) are covered and which aren't.

## Critical Untested Areas
Prioritize finding untested code in these categories (highest risk first):
1. **Financial/payment logic** — any code touching money, subscriptions, or transactions.
2. **Authentication/authorization** — login, token refresh, permission checks.
3. **Data persistence** — save, delete, migration, corruption recovery.
4. **Network error handling** — timeout, no-connectivity, server error, malformed response.
5. **User input validation** — forms, search queries, file uploads.
6. **Edge cases** — empty collections, null values, maximum lengths, unicode/emoji input, concurrent access.
7. **State transitions** — app/session lifecycle, navigation flows, multi-step processes.

## Missing Test Types
- **Unit Tests**: Pure logic tests with mocked dependencies.
- **Integration Tests**: Testing 2+ real components together (e.g., ViewModel + Service, Controller + DB).
- **Snapshot / Golden Tests**: UI or output appearance verification.
- **Performance Tests**: Benchmarks for critical paths.
- **Concurrency Tests**: Race condition and thread-safety detection.
- **Contract Tests**: API schema and response format verification.

## For each gap found, generate a complete test stub:
```
// MARK: - [ClassName]Tests

[TestClass] [ClassName]Tests {
    
    // System Under Test
    [sut]: [ClassName]
    [mock]: Mock[Dependency]
    
    setUp() {
        mock = Mock[Dependency]()
        sut = [ClassName](dependency: mock)
    }
    
    tearDown() {
        sut = nil
        mock = nil
    }
    
    test_[methodName]_when[Condition]_should[ExpectedBehavior]() {
        // Given
        …
        // When
        …
        // Then
        assert(…)
    }
}
```

End with a **Test Health Dashboard**:
| Module | Files | Tested | Coverage % | Priority |
|--------|-------|--------|-----------|----------|

And a **Test Pyramid** assessment: ratio of Unit / Integration / UI tests vs. ideal.
"""
                ),
                (
                    title: "aiprompts.prompt.unitTestAudit.title".localized,
                    description: "aiprompts.prompt.unitTestAudit.desc".localized,
                    prompt: """
You are a test-quality specialist. Audit all existing tests in my project for reliability and maintainability, regardless of language or test framework.

## Test Quality Checks

### Naming & Structure
- Do test names clearly describe the scenario and expected behavior (e.g., `test_methodName_whenCondition_shouldBehavior`)?
- Is each test focused on exactly one behavior (not testing multiple things)?
- Is the Arrange-Act-Assert (Given-When-Then) structure clear?
- Are tests grouped logically by the class/feature they test?

### Test Independence
- Do any tests depend on execution order? (shared mutable state between tests)
- Are setup/teardown routines properly cleaning up all created resources?
- Do tests rely on real file system, network, database, or clock?
- Are there tests that pass alone but fail when run with the suite (or vice versa)?

### Assertion Quality
- **Weak assertions**: Generic truthy checks where specific equality checks are possible.
- **Missing assertions**: Tests that exercise code but don't assert outcomes.
- **Poorly messaged assertions**: Failures that don't describe what was expected vs. actual.
- **Over-assertion**: Tests asserting on incidental implementation details that break on valid refactors.

### Mock/Stub Quality
- Are mocks verifying interactions (calls made) or just providing stubs?
- Are mocks too complex (reimplementing real logic)?
- Are there real objects (network, DB, disk) used where test doubles should be?

### Flaky Test Indicators
- Tests using real timers, `sleep()`, or fixed delays.
- Tests depending on date/time without controlling the clock.
- Tests with race conditions (accessing shared state from multiple threads/coroutines).
- Tests depending on environment locale, timezone, or external service availability.

### Missing Edge Cases
For each tested method, check:
- Empty / null / undefined input
- Boundary values (0, -1, max value, empty string)
- Error/exception paths
- Concurrent access scenarios

## Output per test file
```
## [TestFile]
Total tests: N | Passing: N | Quality Score: A–F

| Test Name | Issue | Severity | Fix |
|-----------|-------|----------|-----|
```

End with:
1. **Overall Test Suite Quality Score** (A–F)
2. **Flaky Risk Assessment** — which tests are most likely to fail intermittently
3. **Top-10 Test Improvements** sorted by impact
"""
                ),
                (
                    title: "aiprompts.prompt.testGenerator.title".localized,
                    description: "aiprompts.prompt.testGenerator.desc".localized,
                    prompt: """
You are an expert test engineer. I will provide you with a source file. Generate comprehensive, production-quality unit tests for it — using whatever language and test framework the project already uses.

## Requirements

### Test Structure
- Identify the testing framework in use (Jest, pytest, JUnit, XCTest, Go testing, RSpec, etc.) and follow its conventions.
- Create a separate test class/suite for each public type in the file.
- Use proper setup/teardown/beforeEach/afterEach for resource management.
- Name tests clearly: `test_[method]_when[Condition]_should[Result]` or equivalent convention.

### Coverage Goals
For each public method/function/property, write tests for:
1. **Happy path** — Normal expected usage.
2. **Edge cases** — Empty input, null/nil/undefined, zero, negative numbers, very large values, special characters, emoji.
3. **Error paths** — What happens when something goes wrong (exceptions, rejected promises, error returns).
4. **Boundary conditions** — Min/max values, off-by-one scenarios.
5. **State transitions** — If the object has state, test all valid transitions.

### Mocking Strategy
- Create mock/stub/fake objects for all external dependencies (network, database, file system, clock).
- Mocks should track: call count, arguments received, and allow configurable return values.
- Use the language-appropriate pattern (spy, stub, mock, fake, in-memory double).

### Async Test Support
- Properly handle async/await, promises, callbacks, or coroutines in tests.
- Set reasonable timeouts.
- Ensure cleanup even when async tests fail.

### Quality Standards
- Each test must have exactly ONE assertion focus (though multiple assertions are fine if testing one behavior).
- No test should depend on another test's execution.
- No hardcoded real-time delays — use fake timers or async utilities.
- Comments explaining non-obvious test reasoning.

Generate the complete test file(s) ready to copy into the project, including all imports and mock definitions.
"""
                )
            ]
        ),
        
        // ────────────────────────────────────────
        // MARK: 5 · Documentation
        // ────────────────────────────────────────
        (
            title: "aiprompts.category.documentation".localized,
            icon: "doc.text",
            prompts: [
                (
                    title: "aiprompts.prompt.apiDocs.title".localized,
                    description: "aiprompts.prompt.apiDocs.desc".localized,
                    prompt: """
You are a technical writer specializing in developer API documentation. Generate comprehensive documentation for my project that matches the conventions of the language and tooling in use (JSDoc, Javadoc, Docstring, DocC, KDoc, Rustdoc, XML docs, etc.).

## For every public type (class, interface, struct, enum, trait, protocol), generate:

```
/**
 * A brief one-line summary of what this type does.
 *
 * A detailed description paragraph explaining:
 * - The purpose and responsibility of this type
 * - When and why a developer would use it
 * - Key design decisions or constraints
 *
 * @example
 * const instance = new MyType(param);
 * const result = instance.doSomething();
 *
 * @remarks Any important caveats or threading considerations.
 * @see RelatedType, RelatedInterface
 * @since 1.0.0
 */
```

## For every public method / function / property, generate:
```
/**
 * Brief one-line summary.
 *
 * Detailed explanation of behavior, including:
 * - What the method does step by step
 * - Side effects (state mutations, events emitted, I/O performed)
 * - Thread/concurrency safety characteristics
 * - Performance characteristics if relevant (O(n), blocking, etc.)
 *
 * @param paramName - What this parameter controls and valid ranges/values.
 * @returns What the return value represents and possible values.
 * @throws ErrorType when [condition].
 * @complexity O(n) where n is the number of items.
 */
```

## Additional Documentation Artifacts
1. **Getting Started Guide**: Minimum working example from zero to first result.
2. **Architecture Overview**: High-level module and data flow diagram.
3. **CHANGELOG.md** template for future versions.
4. **Migration Guide** template for breaking API changes.

Adapt the documentation format exactly to the conventions of the language used in my project. Generate all documentation ready to paste into the source files.
"""
                ),
                (
                    title: "aiprompts.prompt.readmeDocs.title".localized,
                    description: "aiprompts.prompt.readmeDocs.desc".localized,
                    prompt: """
You are a developer-experience specialist. Analyze my project and generate complete project documentation.

## Generate a comprehensive README.md with these sections:

### Header
- Project name with logo/badge area
- One-line description
- Build status, version, license, platform badges (placeholder URLs)

### Overview
- 3-5 sentence project description
- Key features list with emoji bullets
- Screenshot/GIF placeholder section

### Table of Contents
- Auto-generated from section headers

### Requirements
- Runtime / language version requirements
- Build tool / compiler version
- System / OS dependencies
- Any required environment variables or config

### Installation
- Package manager instructions (npm, pip, cargo, gradle, spm, etc. — whichever apply)
- Manual installation steps
- Step-by-step with code blocks

### Quick Start
- Minimum code to get something working
- 3-step getting started guide

### Architecture
- Layer diagram (Mermaid or ASCII)
- Module descriptions
- Data flow explanation

### Usage Guide
For each major feature:
- Description
- Code example
- Configuration options
- Common pitfalls

### API Reference
- Link to generated API documentation
- Key types/functions and their purposes

### Configuration
- All configurable settings
- Environment variables
- Build configurations / feature flags

### Testing
- How to run tests
- Test coverage info
- How to add new tests

### Contributing
- Code style guidelines
- Branch naming convention
- PR template
- Code review checklist

### Troubleshooting
- Common issues and solutions
- FAQ section
- Debug tips

### License
- License text or reference

### Acknowledgments
- Third-party libraries used
- Credits

Generate the complete README.md file in Markdown format, ready to use.
"""
                ),
                (
                    title: "aiprompts.prompt.commentsAudit.title".localized,
                    description: "aiprompts.prompt.commentsAudit.desc".localized,
                    prompt: """
You are a code-documentation specialist. Audit all comments in my project.

## Comment Categories to Analyze

### Outdated/Stale Comments
- Comments that describe code that has since been changed.
- Parameter descriptions that don't match current function signatures.
- TODO/FIXME comments older than 6 months (check git blame if possible).
- Version-specific comments for versions no longer supported.

### Low-Quality Comments
- Comments that restate the code: `// increment counter` above `counter += 1`.
- Comments explaining "what" instead of "why".
- Commented-out code blocks (should be deleted — git has history).
- Auto-generated comments that were never customized.
- Joke/frustration comments ("// don't touch this", "// here be dragons", "// I have no idea why this works").

### Missing Comments
- Public APIs without any documentation.
- Complex algorithms without explanation of the approach.
- Business rules without reference to requirements/tickets.
- Non-obvious workarounds without linking to the bug they address.
- Regex patterns without explanation.
- Magic numbers/values without context.

### Comment Improvement Opportunities
- Long block comments that should use the language's structured documentation format (JSDoc, Javadoc, Docstring, DocC, KDoc, XML docs, etc.).
- Inline comments on complex types that should be proper documentation comments.
- Missing section dividers / region markers in large files (e.g., `// MARK: -`, `#region`, `// ---`).
- Missing section markers for protocol/interface implementations.

## Output Format
```
## [FileName]

### 🗑 Remove (outdated/noise)
Line XX: `// old comment` — Reason: …

### ✏️ Rewrite (inaccurate/unclear)
Line XX: Current: `// comment`
Suggested: `/** Improved documentation... */`

### ➕ Add (missing documentation)
Line XX: Missing doc for `methodName()`
Suggested:
/**
 * Brief description
 * @param name - ...
 * @returns ...
 */

### 📂 Organize (structural improvements)
Suggestion: Add section markers for [groups]
```

End with a **Documentation Debt Score** (A–F) and prioritized action items.
"""
                )
            ]
        ),
        
        // ────────────────────────────────────────
        // MARK: 6 · Testing & Debugging
        // ────────────────────────────────────────
        (
            title: "aiprompts.category.debugging".localized,
            icon: "ant",
            prompts: [
                (
                    title: "aiprompts.prompt.crashBugAudit.title".localized,
                    description: "aiprompts.prompt.crashBugAudit.desc".localized,
                    prompt: """
You are a senior debugging specialist. I will provide you with a crash log, error message, or bug description. Systematically diagnose the root cause.

## Analysis Framework

### Step 1: Reproduce Understanding
- What is the exact error message or crash signature?
- What is the call stack? Analyze each frame.
- What user action triggers it? Is it consistent or intermittent?

### Step 2: Root Cause Analysis (5 Whys)
Apply the "5 Whys" technique:
1. Why did the crash happen? → [immediate cause]
2. Why did [immediate cause] happen? → [deeper cause]
3. Why did [deeper cause] happen? → [systemic cause]
4. Why did [systemic cause] happen? → [design flaw]
5. Why does [design flaw] exist? → [process gap]

### Step 3: Code Analysis
- Identify the exact line(s) of code responsible.
- Trace data flow backward from the crash point to the origin of bad data.
- Check for common patterns at the crash site:
  - Force unwrap of nil
  - Array index out of bounds
  - Unhandled enum case
  - Thread safety violation
  - Deallocated object access
  - Stack overflow from recursion

### Step 4: Fix
Provide:
1. **Immediate fix**: Minimum change to prevent the crash.
2. **Proper fix**: Correct solution addressing the root cause.
3. **Defensive fix**: Additional safety measures (guards, assertions, logging).

### Step 5: Prevention
- Unit test that would catch this bug.
- Static analysis rule that could prevent it.
- Code review checklist item to add.

### Step 6: Regression Check
- Other places in the codebase with the same pattern.
- Related code that might have the same bug.

## Output Format
```
## 🐛 Bug Diagnosis Report

**Crash Type**: [EXC_BAD_ACCESS / Fatal Error / etc.]
**Root Cause**: [One sentence]
**Affected Users**: [Estimated impact]

### Analysis
[Detailed 5-Whys analysis]

### Fix (Immediate)
[Code]

### Fix (Proper)
[Code]

### Regression Check
[List of similar code locations]

### Prevention Test
[Test code]
```
"""
                ),
                (
                    title: "aiprompts.prompt.instrumentsGuide.title".localized,
                    description: "aiprompts.prompt.instrumentsGuide.desc".localized,
                    prompt: """
You are a profiling and observability expert. Analyze my project and create a custom performance profiling guide tailored to its stack.

## For my specific project, generate:

### 1. Performance Profiling Checklist
Based on my code, identify the top-5 areas most likely to have performance issues, and for each provide:
- Which profiling tool to use for this language/platform (e.g., Chrome DevTools, Xcode Instruments, async-profiler, py-spy, pprof, perf, Datadog APM, etc.).
- Exactly what to look for in the profile/trace.
- What "good" vs "bad" numbers look like for this specific operation.
- Step-by-step instructions to reproduce and measure.

### 2. Memory Profiling Guide
- How to take heap snapshots or memory profiles relevant to my stack.
- Key objects/allocations to watch based on my model/service classes.
- Expected memory footprint for typical usage.
- Triggers to test: navigation / page transitions, data refresh, media loading, bulk operations.

### 3. Custom Instrumentation Code
Provide tracing/instrumentation code for my project's critical paths using the appropriate mechanism for my stack:
```
// Example: trace spans, log markers, or timing probes
startSpan("API Call", tags: { endpoint })
// ... operation ...
endSpan("API Call")
```

### 4. Automated Performance Regression Tests
Generate benchmark/performance test stubs for:
- Application startup / cold start time
- Key screen or page transition times
- Data loading time with representative dataset sizes
- Search/filter performance with large datasets

### 5. Performance Budget
Define performance budgets for my application:
| Metric | Target | Warning | Critical |
|--------|--------|---------|----------|
| Startup (cold) | < 1s | 1-2s | > 2s |
| Page/screen transition | < 0.3s | 0.3-0.5s | > 0.5s |
| Memory (idle) | < 50MB | 50-100MB | > 100MB |
| API response (p95) | < 200ms | 200-500ms | > 500ms |

Customize these budgets based on my app's complexity and typical usage patterns.
"""
                )
            ]
        ),
        
        // ────────────────────────────────────────
        // MARK: 7 · API & Networking
        // ────────────────────────────────────────
        (
            title: "aiprompts.category.networking".localized,
            icon: "network",
            prompts: [
                (
                    title: "aiprompts.prompt.networkAudit.title".localized,
                    description: "aiprompts.prompt.networkAudit.desc".localized,
                    prompt: """
You are a networking-layer architect. Perform a comprehensive audit of my project's network code.

## API Design & Structure
- Is there a centralized networking layer or are API calls scattered?
- Is there a proper request builder / router pattern?
- Are endpoints defined as an enum or constants (not hardcoded strings)?
- Is the base URL configurable per environment (dev/staging/prod)?
- Are API versions handled properly?

## Request Handling
- Are all requests using async/await (modern) or completion handlers (legacy)?
- Is there a unified request method that handles common concerns?
- Are request headers set consistently (auth token, content-type, accept, user-agent)?
- Is there request retry logic for transient failures (5xx, timeout)?
- Is there request deduplication (preventing the same request from firing concurrently)?
- Are requests cancellable when the UI is dismissed?

## Response Handling
- Is response deserialization (JSON, XML, Protobuf, etc.) using a typed schema with proper error handling?
- Are date formats handled consistently (ISO8601, custom)?
- Are optional vs required fields properly modeled?
- Is pagination implemented correctly (cursor, offset, or link-based)?
- Are empty/no-content responses (204) handled without deserialization errors?

## Error Handling
- Is there a typed error model covering: network unavailable, timeout, server error, auth expired, rate limited, maintenance mode, parsing error?
- Are HTTP status codes mapped to proper error types?
- Are errors surfaced to the user with actionable messages?
- Is there automatic token refresh on 401 with request replay?
- Are errors logged/reported to observability tooling?

## Security
- Is certificate pinning implemented for critical endpoints?
- Are auth tokens stored in a secure store (not plain-text config, cookies, or local storage)?
- Is sensitive data excluded from request/response logging?
- Are requests using HTTPS exclusively?

## Performance
- Is response caching implemented (HTTP cache headers, ETag/If-None-Match, custom cache)?
- Are images and media loaded with progressive/lazy loading?
- Is there request batching for multiple related calls?
- Are large downloads using background/streaming downloads?

## Generate:
1. A **network layer architecture diagram** (text-based)
2. An **ideal network layer implementation** for my project (protocol + concrete class)
3. A **migration plan** if the current implementation needs refactoring
"""
                ),
                (
                    title: "aiprompts.prompt.apiMock.title".localized,
                    description: "aiprompts.prompt.apiMock.desc".localized,
                    prompt: """
You are a testing infrastructure specialist. Create a comprehensive API mocking and testing setup for my project, adapting code examples to the language and framework in use.

## Generate the following:

### 1. HTTP Interceptor / Mock Transport Layer
Implement an HTTP intercept mechanism appropriate for the project's language/framework (e.g., mock fetch adapter, WireMock, MockWebServer, custom URLProtocol, nock, msw, etc.) that allows tests to intercept and stub all outgoing HTTP requests.

### 2. API Response Fixtures
For each API endpoint in my project, create:
- **Success response** JSON fixture with realistic data.
- **Error response** fixtures for each possible error (400, 401, 403, 404, 422, 500, 503).
- **Edge case responses**: Empty arrays, null fields, extremely large payloads, malformed JSON.
- **Paginated response** fixtures with next/previous page metadata.

### 3. Mock Service / Client Classes
For each networking service/client, create a test double:
```
class MockAPIService implements APIServiceInterface {
    responses: Map<string, Result | Error>
    callLog: Array<{ method: string, params: any }>
    // Track what was called and return configurable responses
}
```
Adapt the pattern to the language's idiomatic mocking approach (spy, stub, fake, in-memory double).

### 4. Network Test Helpers
- Helper to simulate network delays.
- Helper to simulate network disconnection.
- Helper to simulate slow/flaky connections.
- Helper to verify request headers, body, and query parameters.

### 5. Integration Test Scenarios
Generate test cases for:
- Happy path for each API endpoint.
- Token expiry → refresh → retry flow.
- Network offline → queue request → send when online.
- Concurrent requests to the same endpoint.
- Request cancellation when caller is destroyed.
- Pagination (load more).

### 6. Mock Server Configuration (Optional)
If applicable, generate a local mock server setup (json-server, WireMock standalone, MSW service worker, etc.) for end-to-end / UI testing.

Provide all code ready to add to the project's test target.
"""
                )
            ]
        ),
        
        // ────────────────────────────────────────
        // MARK: 8 · Accessibility
        // ────────────────────────────────────────
        (
            title: "aiprompts.category.accessibility".localized,
            icon: "accessibility",
            prompts: [
                (
                    title: "aiprompts.prompt.a11yAudit.title".localized,
                    description: "aiprompts.prompt.a11yAudit.desc".localized,
                    prompt: """
You are an accessibility specialist for Apple platforms. Audit my project for WCAG 2.1 AA compliance and Apple HIG accessibility guidelines.

## VoiceOver Support
- Are all interactive elements (buttons, links, toggles) reachable via VoiceOver?
- Do all images have `.accessibilityLabel()` or are decorative images marked `.accessibilityHidden(true)`?
- Are custom controls providing proper `.accessibilityTraits()` (button, header, link, etc.)?
- Is `.accessibilityValue()` set for controls with state (sliders, toggles, progress)?
- Is `.accessibilityHint()` provided for non-obvious actions?
- Are grouped elements using `.accessibilityElement(children: .combine)` or `.contain`?
- Is the VoiceOver reading order logical (`.accessibilitySortPriority()`)?
- Are screen transitions announced?
- Are loading states announced via `AccessibilityNotification.Announcement`?
- Are error messages announced when they appear?

## Dynamic Type
- Are all text elements using `.font(.body)`, `.font(.headline)`, etc. (not hardcoded sizes)?
- Do views adapt their layout when text size increases to AX5 (Accessibility Extra Extra Extra Large)?
- Are minimum touch targets 44x44 points?
- Do scrollable containers accommodate larger text without clipping?
- Are icons scaling with text or using SF Symbols with `.imageScale()`?

## Color & Visual
- Check all text/background color combinations for WCAG AA contrast ratio (4.5:1 for normal text, 3:1 for large text).
- Is information conveyed by color alone? (Must have secondary indicator: icon, pattern, label.)
- Is the UI usable in: Light mode, Dark mode, Increased Contrast, Reduce Transparency, Reduce Motion?
- Are focus indicators visible for keyboard navigation?

## Motor Accessibility
- Can all features be accessed via keyboard-only navigation?
- Are keyboard shortcuts provided for common actions?
- Are drag-and-drop interactions providing accessible alternatives?
- Is the UI compatible with switch access and alternative input devices?

## Cognitive Accessibility
- Are error messages clear and actionable?
- Is navigation consistent across screens?
- Are destructive actions requiring confirmation?
- Are animations respectful of Reduce Motion preference?

## For each issue found:
```
📍 File:Line
🏷 WCAG Criterion: [e.g., 1.1.1 Non-text Content]
🔴 Severity: Critical / Major / Minor
❌ Issue: [Description]
✅ Fix:
```swift
// Code to add/change
```
```

End with an **Accessibility Score Card** (per screen) and a **VPAT-style compliance matrix** (Supports / Partially Supports / Does Not Support) for key WCAG criteria.
"""
                )
            ]
        ),
        
        // ────────────────────────────────────────
        // MARK: 9 · i18n & Localization
        // ────────────────────────────────────────
        (
            title: "aiprompts.category.localization".localized,
            icon: "globe",
            prompts: [
                (
                    title: "aiprompts.prompt.i18nAudit.title".localized,
                    description: "aiprompts.prompt.i18nAudit.desc".localized,
                    prompt: """
You are an internationalization (i18n) and localization (l10n) specialist. Perform a complete audit of my project.

## 1 · Hardcoded Strings
Scan every source file for user-visible strings that are NOT using the localization system:
- UI labels, button titles, alert messages, placeholder text.
- Error messages shown to users.
- Accessibility labels and hints.
- Notification content.
- String interpolation that concatenates user-visible text (sentence structure varies by language).

For each, provide the file, line, current string, and the localized replacement using the project's i18n system:
```
// Before
Label: "No results found"

// After
Label: i18n.t("no_results_found")  // Empty state message when search returns no results
```
(Adapt the syntax to the project's actual i18n framework: i18next, GNU gettext, Android strings.xml, Apple .strings, etc.)

## 2 · Localization File Audit
For each localization resource file (`.strings`, `.stringsdict`, `.po`, `.arb`, `messages.json`, `strings.xml`, XLIFF, etc.):
- Keys present in base language but missing in other languages.
- Keys present in translations but removed from base (zombie keys).
- Keys used in code but not present in any localization file.
- Inconsistent placeholder format between languages (`%@`, `%d`, `{0}`, `{{name}}` mismatch).
- Missing plural rules for strings that include a count.

## 3 · Date, Time & Number Formatting
- Dates formatted without using a locale-aware formatter (e.g., `DateFormatter`, `Intl.DateTimeFormat`, `moment.locale()`, etc.).
- Numbers displayed without locale-aware number formatting.
- Currency amounts not using locale-appropriate symbols and positioning.
- Distances/measurements not using locale-appropriate units.
- Hardcoded date formats like "MM/dd/yyyy" (varies by locale).

## 4 · Layout & RTL Support
- Fixed directional layout that doesn't flip for RTL languages?
- Text alignment hardcoded as left/right instead of start/end or leading/trailing?
- Icons with directional meaning (arrows, chevrons) not mirrored for RTL?
- Text truncation issues with longer translations (German, Finnish)?
- Flex/grid layouts that assume LTR order?

## 5 · String Concatenation Anti-Patterns
- `"Hello, " + name + "!"` → word order differs by language. Use full sentence templates with named placeholders.
- Sentence fragments assembled from parts → use complete sentences with placeholders.
- Gendered strings without language-appropriate variants.

## Output
Generate a **Localization Health Report**:
| Category | Issues Found | Critical | Action Items |
|----------|-------------|----------|-------------|

And a complete **missing-keys list** for each language, ready to hand to translators.
"""
                )
            ]
        ),
        
        // ────────────────────────────────────────
        // MARK: 10 · Git & CI/CD
        // ────────────────────────────────────────
        (
            title: "aiprompts.category.cicd".localized,
            icon: "arrow.triangle.branch",
            prompts: [
                (
                    title: "aiprompts.prompt.gitWorkflow.title".localized,
                    description: "aiprompts.prompt.gitWorkflow.desc".localized,
                    prompt: """
You are a Git workflow consultant. Audit my project's Git practices and suggest improvements.

## Repository Health
- **Large files in history**: Scan for files > 1MB that shouldn't be in Git (binaries, archives, generated files). Suggest git-lfs or BFG Repo-Cleaner.
- **Sensitive data in history**: API keys, passwords, certificates, .env files ever committed. Provide cleanup commands.
- **.gitignore audit**: Missing entries for: build output directories, IDE-specific files, OS-specific files (.DS_Store, Thumbs.db), dependency caches (node_modules, .gradle, .cargo, venv, SPM caches, Pods), environment files (.env), generated code, compiled artifacts.
- **Repository size**: Is it bloated? Top-10 largest files by history contribution.

## Branch Strategy
- Current branch structure analysis.
- Recommended branching model for my project size:
  - Solo: trunk-based with tags
  - Small team: GitHub Flow (main + feature branches)
  - Large team: Git Flow (main, develop, feature, release, hotfix)
- Branch naming convention: `feature/TICKET-123-description`, `bugfix/...`, `release/1.2.0`.
- Branch protection rules to implement.

## Commit Quality
- Analyze recent 50 commits for:
  - Conventional Commits format compliance (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`, `test:`).
  - Commit message quality (descriptive subject, body explaining "why").
  - Commit granularity (atomic commits vs "WIP" dumps).
  - Large commits that should be split.
- Generate a commit message template (`.gitmessage`):
```
type(scope): subject

body

footer
```

## Git Hooks
Generate useful Git hooks for my project:
- **pre-commit**: Lint check, format check, no-debug-code check.
- **commit-msg**: Validate conventional commit format.
- **pre-push**: Run unit tests.

## Workflow Automation
- PR template (`.github/PULL_REQUEST_TEMPLATE.md`) customized for my project type.
- Issue templates for bugs and features.
- Release checklist.

Provide all files and configurations ready to add to the repository.
"""
                ),
                (
                    title: "aiprompts.prompt.cicdPipeline.title".localized,
                    description: "aiprompts.prompt.cicdPipeline.desc".localized,
                    prompt: """
You are a DevOps engineer specializing in software delivery pipelines. Design a complete CI/CD pipeline for my project, regardless of language or platform.

## Pipeline Stages

### 1. Build Stage
- Compile / transpile / bundle the project using the appropriate build tool.
- Dependency installation and caching strategy (node_modules, .gradle cache, SPM, pip, Cargo, etc.).
- Parallel build optimization where applicable.
- Estimated time target for each step.

### 2. Quality Gate Stage
- Linting and formatting checks (ESLint, SwiftLint, Checkstyle, Ruff, Clippy, etc.).
- Unit test execution with code coverage reporting.
- Integration test execution.
- Static analysis and code complexity metrics.
- Security vulnerability scanning (Snyk, Dependabot, OWASP, etc.).
- Code coverage threshold enforcement (e.g., fail if < 70%).

### 3. Analysis Stage
- Code quality trend tracking (SonarQube, CodeClimate, or equivalent).
- Binary/artifact size tracking and alerts.
- Dependency audit (outdated or vulnerable packages).
- Performance regression detection.

### 4. Distribution Stage
- **Development**: Auto-deploy to staging/test environment on merge to `develop` / `main`.
- **Staging**: Deploy to pre-production on release branch.
- **Production**: Deploy on version tag (e.g., `v*`).
- Artifact versioning and storage.
- Release notes generation from commit messages.

### 5. Post-Deploy Stage
- Smoke tests / health checks after deployment.
- Error rate monitoring (first 24 hours).
- Performance baseline comparison.
- Automated rollback trigger conditions.

## Generate Configuration Files
Based on my project, generate ready-to-use CI configuration for the most appropriate platform:
- GitHub Actions (`.github/workflows/`)
- GitLab CI (`.gitlab-ci.yml`)
- Jenkins / Jenkinsfile
- CircleCI / Bitbucket Pipelines / Azure DevOps

Include:
- Caching strategy for fast builds.
- Secret management (environment variables / vault).
- Notification setup (Slack / Discord / email).
- Badge generation for README.
- Artifact storage and retention policy.

## Cost & Time Estimates
Provide estimated build times and CI costs per month based on typical usage (10 PRs/week, 2 releases/month).
"""
                )
            ]
        ),
        
        // ────────────────────────────────────────
        // MARK: 11 · Dependency Management
        // ────────────────────────────────────────
        (
            title: "aiprompts.category.dependencies".localized,
            icon: "shippingbox",
            prompts: [
                (
                    title: "aiprompts.prompt.depAudit.title".localized,
                    description: "aiprompts.prompt.depAudit.desc".localized,
                    prompt: """
You are a dependency management specialist. Perform a thorough audit of all third-party dependencies in my project.

## For each dependency, analyze:

### 1. Necessity
- Is this dependency actually used? (Check import/require statements and actual usage.)
- Could this be replaced with a built-in / standard library feature? (e.g., a heavy HTTP client replaced by built-in fetch/URLSession, a JSON library replaced by native JSON support, a utility library replaced by language builtins)
- Is only a small part used? Would copying the relevant code be simpler than maintaining the dependency?

### 2. Health & Maintenance
- Last commit date — is it actively maintained?
- Open issues count and response time.
- Number of contributors.
- Is there a bus factor risk (single maintainer)?
- Language/runtime version compatibility with the current project stack.
- Does it support the latest toolchain and target platform versions?

### 3. Security
- Known CVEs or security advisories.
- Does it request unnecessary permissions or entitlements?
- Does it include analytics or tracking code?
- Has the dependency been compromised in the past?

### 4. License Compliance
- License type (MIT, Apache 2.0, GPL, etc.).
- Is the license compatible with my project's distribution model (commercial, open-source, SaaS, App Store, etc.)?
- Are attribution requirements met (NOTICES file)?
- Any copyleft licenses that could be problematic?

### 5. Version Management
- Am I on the latest version? What's changed since my version?
- Are there breaking changes in the latest major version?
- Migration guide if an upgrade is needed.
- Is the version range too permissive (accepting any next major version, e.g., `^1.0.0` accepting `2.x`, or equivalent in your package manager)?

## Output: Dependency Report Card
| Dependency | Version | Latest | License | Health | Risk | Action |
|-----------|---------|--------|---------|--------|------|--------|

### Risk Ratings
- 🟢 **Low**: Active, well-maintained, MIT/Apache, no CVEs.
- 🟡 **Medium**: Slightly outdated, or single maintainer, or minor issues.
- 🔴 **High**: Unmaintained, known CVEs, license issues, or massive dependency it could be replaced.

End with:
1. **Immediate Actions**: Dependencies to update or replace now.
2. **Native Migration Plan**: Dependencies replaceable with Apple frameworks, with migration code samples.
3. **Total Dependency Weight**: Estimated impact on binary size and build time.
"""
                )
            ]
        ),
        
        // ────────────────────────────────────────
        // MARK: 12 · Code Generation
        // ────────────────────────────────────────
        (
            title: "aiprompts.category.codeGeneration".localized,
            icon: "wand.and.stars",
            prompts: [
                (
                    title: "aiprompts.prompt.crudGen.title".localized,
                    description: "aiprompts.prompt.crudGen.desc".localized,
                    prompt: """
You are a full-stack developer. I will give you an entity name and its properties. Generate a complete CRUD feature following my project's architecture and language.

## Generate the following components:

### 1. Model / Entity
```
[Entity] {
    id: UUID / auto-increment ID
    // domain properties
    createdAt: DateTime
    updatedAt: DateTime
}
```
- Include serialization/deserialization support matching my project (Codable, Jackson, Pydantic, Zod, etc.).
- Include field validation rules.
- Include mock/fixture data for testing and previews.

### 2. Service / Repository
```
interface [Entity]Service {
    fetchAll(): Promise<[Entity][]>
    fetchById(id): Promise<[Entity]>
    create(data): Promise<[Entity]>
    update(id, data): Promise<[Entity]>
    delete(id): Promise<void>
    search(query): Promise<[Entity][]>
}
```
- Concrete implementation with proper error handling.
- Caching layer where applicable.
- Offline / optimistic update consideration.

### 3. ViewModel / Controller / Store
```
[Entity]Store / ViewModel {
    items: [Entity][]
    selectedItem: [Entity] | null
    isLoading: boolean
    error: AppError | null
    searchQuery: string
    
    // CRUD methods
    // Search/filter
    // Pagination
    // Sort options
}
```

### 4. UI / Views / Components
- **List View**: With search, sort, filter, pull-to-refresh, pagination, empty state, error state, loading state.
- **Detail View**: Full entity display with edit/delete actions.
- **Create/Edit Form**: With validation, loading state, error feedback.
- **Row/Card Component**: Compact representation for lists.

### 5. Tests
- Unit tests for all CRUD operations covering happy paths and error paths.
- Mock service/repository for testing.

Match my project's existing code style, naming conventions, and architecture patterns exactly. Study my existing files before generating.
"""
                ),
                (
                    title: "aiprompts.prompt.boilerplateGen.title".localized,
                    description: "aiprompts.prompt.boilerplateGen.desc".localized,
                    prompt: """
You are a project scaffolding specialist. Analyze my existing project structure and generate boilerplate for a new feature module that perfectly matches the conventions already in use.

## Analysis Phase
First, analyze my project to understand:
1. **Language & framework**: What language, framework, and version is the project using?
2. **Architecture pattern**: MVC, MVVM, Clean Architecture, Redux, BLoC, VIPER, Hexagonal, etc.
3. **File organization**: By feature (vertical slices) or by type (horizontal layers)?
4. **Naming conventions**: Suffixes, prefixes, casing style (camelCase, snake_case, PascalCase).
5. **Common patterns**: How are services initialized? How is navigation/routing handled? How is state managed?
6. **Dependency injection**: Constructor injection, DI container, service locator?
7. **Code style**: Indentation, brace style, import ordering, comment style.

## Generation Phase
Based on the analysis, generate a complete feature module:

### Files to generate:
```
[feature-name]/
├── models/
│   ├── [feature]Model.[ext]
│   └── [feature]Errors.[ext]
├── services/
│   ├── [feature]ServiceInterface.[ext]
│   └── [feature]Service.[ext]
├── viewmodels/ (or controllers/ or stores/)
│   └── [feature]ViewModel.[ext]
├── views/ (or pages/ or components/)
│   ├── [feature]View.[ext]
│   ├── [feature]DetailView.[ext]
│   └── components/
│       ├── [feature]Row.[ext]
│       └── [feature]EmptyState.[ext]
└── tests/
    ├── [feature]ViewModelTests.[ext]
    ├── [feature]ServiceTests.[ext]
    └── mocks/
        └── Mock[feature]Service.[ext]
```

### Each file should:
- Follow the **exact same code style** as existing files.
- Include proper imports/dependencies.
- Include section markers / region comments matching project convention.
- Include documentation comments.
- Include TODO comments where custom logic is needed.
- Compile/run without errors when added to the project.

### Also generate:
- Navigation / routing integration code (how to link to this feature from existing screens).
- Localization keys needed (in the project's i18n format).
- Any required config / registration entries (DI container registration, route registration, etc.).
- Preview / storybook / fixture data for all views.

Tell me the feature name and main entity; I will generate everything matching your project's exact patterns.
"""
                ),
                (
                    title: "aiprompts.prompt.projectReport.title".localized,
                    description: "aiprompts.prompt.projectReport.desc".localized,
                    prompt: """
You are a technical due-diligence consultant. Perform a complete project health assessment.

## 1 · Project Overview
- Language(s) and framework(s) used.
- Estimated total lines of code (LOC) and file count.
- Project age (from first commit to latest).
- Active contributors count.
- Dependency count and types.

## 2 · Code Quality Metrics
| Metric | Value | Rating |
|--------|-------|--------|
| Average function length (lines) | | A–F |
| Average file length (lines) | | A–F |
| Max cyclomatic complexity | | A–F |
| Duplicate code percentage | | A–F |
| Comment/code ratio | | A–F |
| TODO/FIXME count | | Info |
| Force unwrap count | | A–F |
| Test coverage (estimated) | | A–F |

## 3 · Architecture Assessment
- Pattern used and consistency of application.
- Layer separation quality.
- Dependency direction (do dependencies point inward?).
- Module coupling analysis.
- Scalability assessment (what breaks first as the app grows?).

## 4 · Technical Debt Inventory
List every area of technical debt, categorized:
- 🔴 **Critical**: Blocks features or causes production issues.
- 🟡 **Significant**: Slows development or increases bug risk.
- 🟢 **Minor**: Code cleanliness issues, nice-to-fix.

For each item, estimate effort to fix (hours/days).

## 5 · Risk Assessment
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Data loss from X | High/Med/Low | High/Med/Low | … |
| Crash from Y | | | |
| Performance degradation | | | |
| Security breach via Z | | | |
| Key dependency abandoned | | | |

## 6 · Improvement Roadmap
### Phase 1: Quick Wins (This Week)
- Items that take < 2 hours and have high impact.

### Phase 2: Foundation (This Month)
- Architecture improvements, test infrastructure, CI/CD setup.

### Phase 3: Excellence (This Quarter)
- Comprehensive testing, performance optimization, accessibility, documentation.

## 7 · Executive Summary
- 3-sentence project health summary.
- Overall health grade: A–F.
- #1 priority action item.
- Estimated technical debt in developer-days.

Make all assessments honest and specific. Reference actual files and code sections in every finding.
"""
                )
            ]
        )
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                
                ForEach(promptCategories, id: \.title) { category in
                    categorySection(title: category.title, icon: category.icon, prompts: category.prompts)
                }
            }
            .padding(24)
        }
        .background(Color.backgroundSecondary.opacity(0.5))
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("aiprompts.title".localized)
                        .font(.system(size: 28, weight: .bold))
                    
                    Text(String(format: "aiprompts.subtitle".localized, promptCategories.count, promptCategories.flatMap(\.prompts).count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("aiprompts.description".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
                .padding(.top, 8)
        }
    }
    
    private func categorySection(title: String, icon: String, prompts: [(title: String, description: String, prompt: String)]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.title2.bold())
            }
            
            LazyVGrid(columns: promptGridColumns, alignment: .leading, spacing: 20) {
                ForEach(prompts, id: \.title) { promptItem in
                    PromptCard(
                        title: promptItem.title,
                        description: promptItem.description,
                        prompt: promptItem.prompt
                    )
                }
            }
        }
    }
}


#Preview {
    AIPromptsContentView()
}
