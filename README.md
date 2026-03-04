# DevAtlas for macOS

<div align="center">

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

**The all-in-one developer workspace manager for macOS.**  
Scan, analyze, and navigate all your coding projects — without ever leaving your screen.

[Features](#-features) • [Getting Started](#-getting-started) • [Tech Stack](#-tech-stack) • [Contributing](#-contributing)

</div>

---

## What is DevAtlas?

DevAtlas is a native macOS app built with SwiftUI that acts as a **mission control for developers**. It automatically discovers every project on your machine, detects the language and framework, checks your dependencies for updates, analyzes unused code, visualizes Git activity, and lets you jump into any editor with a single click — all from one beautiful, fast interface.

> Supports **20+ languages and frameworks** out of the box: Swift, Node.js, React, Next.js, Vue, Angular, Flutter, Go, Rust, Python, Java, PHP, Ruby, .NET, Docker, and more.

---

## ✨ Features

### 🔍 Intelligent Project Discovery
DevAtlas scans all mounted disks on your Mac and automatically maps every coding project it finds. Projects are auto-categorized into **Web**, **Mobile**, **Desktop**, and **Cloud** — and refreshed in the background as you work.

- Full-disk recursive scan with smart exclusions (`node_modules`, `.git`, `build`, `dist`, etc.)
- Auto-detects project type from marker files (`package.json`, `go.mod`, `pubspec.yaml`, `Dockerfile`, ...)
- Timeline grouping: **Today**, **This Week**, **This Month**, **Older**
- Live search with `⌘P` quick-launch
- Custom exclusion paths for personalized scanning

---

### 🤖 AI-Powered Code Analysis
DevAtlas integrates **40+ AI-powered prompts** across 14 categories to help you improve your codebase. These prompts are designed to work with Claude, ChatGPT, or any LLM of your choice.

#### 📊 Code Quality
| Prompt | Description |
|--------|-------------|
| Unused Code Detection | Comprehensive dead-code audit across your entire project |
| Code Smells | Identify anti-patterns and bloaters (long methods, duplicate code, etc.) |
| Memory Leaks | iOS/macOS-specific memory issue detection |
| Security Audit | White-box security analysis for vulnerabilities |
| Error Handling | Audit error-handling weaknesses that could lead to crashes |

#### ⚡ Performance
| Prompt | Description |
|-------- Bottleneck Analysis|-------------|
| | Holistic performance audit with profiling suggestions |
| SwiftUI Render Optimization | View rendering efficiency improvements |
| App Launch Optimization | Minimize time-to-interactive |

#### 🏗️ Architecture
| Prompt | Description |
|--------|-------------|
| Architecture Review | Comprehensive architecture assessment |
| Design Patterns | Pattern usage analysis and opportunities |
| Refactoring Guide | Martin Fowler-based refactoring suggestions |

#### 🧪 Testing
| Prompt | Description |
| Test Coverage Analysis | Identify|--------|-------------|
 untested code paths |
| Unit Test Audit | Test quality and reliability review |
| Test Generator | Generate production-quality unit tests |

#### 📚 Documentation
| Prompt | Description |
|--------|-------------|
| API Documentation | DocC-compatible documentation generation |
| README Generator | Complete project documentation |
| Comments Audit | Code comment quality review |

#### 🔧 Other Categories
- **Debugging**: Crash analysis, Xcode Instruments guide
- **Networking**: API audit, mocking setup
- **Accessibility**: WCAG 2.1 AA and Apple HIG compliance
- **Localization**: i18n/l10n audit
- **CI/CD**: Git workflow, pipeline design
- **Dependencies**: Third-party dependency audit
- **Code Generation**: CRUD generator, boilerplate generator

---

### 📦 Dependency Management & Version Checker
See all your project's dependencies at a glance — and know instantly which ones are outdated.

| Ecosystem | Manifest File |
|---|---|
| JavaScript / TypeScript | `package.json` |
| Flutter / Dart | `pubspec.yaml` |
| Go | `go.mod` |
| Rust | `Cargo.toml` |
| Swift (SPM) | `Package.swift` |
| Swift (CocoaPods) | `Podfile` |
| Swift (Carthage) | `Cartfile` |
| .NET / C# | `.csproj`, `.sln` |
| Java | `pom.xml`, `build.gradle` |
| Python | `requirements.txt`, `pyproject.toml` |
| PHP | `composer.json` |
| Ruby | `Gemfile` |

DevAtlas fetches the **latest available version** of each package directly from the relevant registry (npm, pub.dev, crates.io, pkg.go.dev, etc.) using concurrent async requests — so you always know what needs updating.

---

### 🧹 Unused Code Analyzer
Dead code is technical debt. DevAtlas scans your source files and highlights symbols that are defined but never used:

- **Swift** — functions, classes, structs, enums, variables
- **C#** — unused classes and methods
- **JavaScript / TypeScript** — unreferenced exports and declarations
- **Dart** — unused declarations

> 💡 **Smart Detection**: The unused code analysis button only appears when your project uses a supported language (Swift, C#, JavaScript, or Dart).

---

### 📊 Project Statistics & Git Insights
A full picture of your codebase health — across every project, at once.

- Total file count and **lines of code** per project
- **Git commit history**: commit count, activity graph, lines added/deleted
- Date-range filtering for Git stats
- **Export** statistics as CSV or JSON
- Interactive **Charts** for visualizing data

---

### 📝 Notebook
A lightweight, project-linked note-taking system built right in.

- Notes and tasks tied to specific projects
- Full **Markdown rendering**
- Tag and category system for quick filtering
- Cross-project search by content, project, or tag
- Todo items with priority levels and status tracking

---

### ⚡ Quick Actions
Stop hunting through Finder. Open any project directly in your preferred editor:

- **VS Code**, **Xcode**, **Cursor**, **Zed**, and more
- Open in **Terminal** or **Finder** with one click
- `⌘P` keyboard shortcut for instant project search
- Run project scripts directly from the app

---

### 🎨 Beautiful UI/UX
- Native macOS look and feel with smooth animations
- Full **Dark Mode** support
- Custom accent colors to match your preference
- Responsive grid layouts

---

### 🌍 Localization & Accessibility
- 10+ languages: English, Turkish, German, French, Italian, Japanese, Korean, Simplified Chinese, and more
- Full **Dark Mode** support
- Native macOS look and feel with smooth animations

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9 |
| UI Framework | SwiftUI 5 |
| Concurrency | Swift Concurrency (`async/await`, `actor`) |
| State Management | `@Observable` (Observation framework) |
| Minimum OS | macOS 14.0 Sonoma |
| Build Tool | Xcode 15+ |

Zero third-party dependencies — built entirely on top of Apple's native frameworks.

---

## 🚀 Getting Started

```bash
git clone https://github.com/aygundev/DevAtlasMac.git
cd DevAtlasMac
open DevAtlasMac.xcodeproj
```

Press `⌘R` in Xcode to build and run. No additional setup required.

**Requirements:** macOS 14.0 or later · Xcode 15.0 or later

---

## 📁 Project Structure

```
DevAtlasMac/
├── DevAtlasMacApp.swift          # App entry point
├── ContentView.swift             # Root view & tab routing
├── Views/
│   ├── Atlas/                    # Project list, grid & detail
│   ├── Stats/                    # Statistics dashboard
│   ├── Notebook/                 # Note-taking
│   ├── Settings/                 # App preferences
│   ├── Onboarding/               # First-launch walkthrough
│   └── AIPrompts/               # AI-powered code analysis
├── ViewModels/                   # Business logic & state
├── Services/
│   ├── ProjectScanner.swift      # Disk-scanning engine
│   ├── DependenciesService.swift
│   ├── VersionCheckerService.swift
│   ├── GitStatsService.swift
│   ├── Dependencies/             # Per-ecosystem manifest parsers
│   └── UnusedCodeAnalyzer/       # Static analysis engine
├── Models/                       # Data models
├── Components/                   # Reusable SwiftUI components
├── Extensions/                   # Swift extensions & helpers
└── *.lproj/                      # Localization strings (10+ languages)
```

---

## 🤝 Contributing

Contributions are welcome!

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Commit your changes: `git commit -m 'Add your feature'`
4. Push: `git push origin feature/your-feature`
5. Open a Pull Request

Please open an issue first for significant changes.

---

## 📄 License

This project is licensed under the MIT License.

---

<div align="center">

Built with ❤️ for macOS developers · Native · Fast · No subscriptions

</div>
