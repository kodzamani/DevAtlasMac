import Foundation

// MARK: - Version Checker Service

/// Fetches the latest available version for dependencies from their respective package registries
actor VersionCheckerService {
    
    // MARK: - Public API
    
    /// Enriches a ProjectDependencies struct with latestVersion info for each dependency
    static func enrichWithLatestVersions(_ dependencies: ProjectDependencies) async -> ProjectDependencies {
        var result = dependencies
        
        // Fetch all concurrently: direct, dev, and all project groups together
        async let direct = fetchLatestVersions(for: result.directDependencies)
        async let dev = fetchLatestVersions(for: result.devDependencies)
        async let groups: [[Dependency]] = withTaskGroup(of: (Int, [Dependency]).self) { group in
            for (i, pg) in result.projectGroups.enumerated() {
                group.addTask {
                    let enriched = await fetchLatestVersions(for: pg.dependencies)
                    return (i, enriched)
                }
            }
            var collected = Array(repeating: [Dependency](), count: result.projectGroups.count)
            for await (i, deps) in group {
                collected[i] = deps
            }
            return collected
        }
        
        result.directDependencies = await direct
        result.devDependencies = await dev
        let enrichedGroupDeps = await groups
        for (i, deps) in enrichedGroupDeps.enumerated() {
            result.projectGroups[i].dependencies = deps
        }
        
        return result
    }
    
    // MARK: - Private Helpers
    
    private static func fetchLatestVersions(for deps: [Dependency]) async -> [Dependency] {
        await withTaskGroup(of: (Int, String?).self) { group in
            for (index, dep) in deps.enumerated() {
                group.addTask {
                    let latest = await fetchLatestVersion(for: dep)
                    return (index, latest)
                }
            }
            
            var updated = deps
            for await (index, latest) in group {
                if let latest = latest {
                    updated[index].latestVersion = latest
                }
            }
            return updated
        }
    }
    
    private static func fetchLatestVersion(for dependency: Dependency) async -> String? {
        guard !dependency.version.isEmpty, dependency.version != "*" else { return nil }
        
        switch dependency.source {
        case .npm, .yarn, .pnpm:
            return await fetchNpmLatest(package: dependency.name)
        case .nuget:
            return await fetchNuGetLatest(package: dependency.name)
        case .pub:
            return await fetchPubLatest(package: dependency.name)
        case .cargo:
            return await fetchCratesLatest(package: dependency.name)
        case .go:
            return await fetchGoLatest(module: dependency.name)
        case .spm:
            return await fetchSPMLatest(for: dependency)
        case .cocoapods:
            return await fetchCocoaPodsLatest(package: dependency.name)
        case .carthage:
            return await fetchCarthageLatest(for: dependency)
        }
    }
    
    // MARK: - npm Registry
    
    private static func fetchNpmLatest(package: String) async -> String? {
        // Scoped packages like @angular/core need URL encoding
        let encoded = package.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? package
        guard let url = URL(string: "https://registry.npmjs.org/\(encoded)/latest") else { return nil }
        return await fetch(url: url) { data in
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let version = json?["version"] as? String else { return nil }
            return isPreRelease(version) ? nil : version
        }
    }
    
    // MARK: - NuGet Registry
    
    private static func fetchNuGetLatest(package: String) async -> String? {
        let lowered = package.lowercased()
        guard let url = URL(string: "https://api.nuget.org/v3-flatcontainer/\(lowered)/index.json") else { return nil }
        return await fetch(url: url) { data in
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let versions = json?["versions"] as? [String]
            // Pick the last stable (non-pre-release) version
            return versions?.last(where: { !isPreRelease($0) })
        }
    }
    
    // MARK: - pub.dev Registry
    
    private static func fetchPubLatest(package: String) async -> String? {
        guard let url = URL(string: "https://pub.dev/api/packages/\(package)") else { return nil }
        return await fetch(url: url) { data in
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let latest = json?["latest"] as? [String: Any]
            guard let version = latest?["version"] as? String else { return nil }
            return isPreRelease(version) ? nil : version
        }
    }
    
    // MARK: - crates.io Registry
    
    private static func fetchCratesLatest(package: String) async -> String? {
        guard let url = URL(string: "https://crates.io/api/v1/crates/\(package)") else { return nil }
        var request = URLRequest(url: url)
        // crates.io requires a User-Agent header
        request.setValue("DevAtlasMac/1.0 (https://github.com)", forHTTPHeaderField: "User-Agent")
        return await fetchRequest(request: request) { data in
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let crate = json?["crate"] as? [String: Any]
            // Prefer max_stable_version which crates.io provides explicitly
            let stable = crate?["max_stable_version"] as? String
            let newest = crate?["newest_version"] as? String
            let candidate = stable ?? newest
            guard let version = candidate, !isPreRelease(version) else { return nil }
            return version
        }
    }
    
    // MARK: - Go Proxy
    
    private static func fetchGoLatest(module: String) async -> String? {
        let encoded = module.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? module
        guard let url = URL(string: "https://proxy.golang.org/\(encoded)/@latest") else { return nil }
        return await fetch(url: url) { data in
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let version = json?["Version"] as? String
            // Strip "v" prefix for consistency
            let stripped = version.map { $0.hasPrefix("v") ? String($0.dropFirst()) : $0 }
            guard let v = stripped, !isPreRelease(v) else { return nil }
            return v
        }
    }
    
    // MARK: - CocoaPods Registry

    private static func fetchCocoaPodsLatest(package: String) async -> String? {
        guard let url = URL(string: "https://trunk.cocoapods.org/api/v1/pods/\(package)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("DevAtlasMac/1.0", forHTTPHeaderField: "User-Agent")
        return await fetchRequest(request: request) { data in
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            // versions array is sorted oldest→newest by CocoaPods trunk
            if let versions = json?["versions"] as? [[String: Any]] {
                let stable = versions
                    .compactMap { $0["name"] as? String }
                    .filter { !isPreRelease($0) }
                    .last
                return stable
            }
            return nil
        }
    }

    // MARK: - GitHub Releases (SPM / Carthage)

    /// Fetches the latest stable release for an SPM dependency via GitHub API.
    private static func fetchSPMLatest(for dependency: Dependency) async -> String? {
        // Need a stable semantic version to compare against
        guard !dependency.version.hasPrefix("branch:"),
              !dependency.version.hasPrefix("rev:")
        else { return nil }

        guard let repoURL = dependency.repositoryURL,
              let ownerRepo = githubOwnerRepo(from: repoURL)
        else { return nil }

        return await fetchGithubLatestRelease(ownerRepo: ownerRepo)
    }

    /// Fetches the latest stable release for a Carthage dependency.
    /// Carthage stores "User/Repo" as the dependency name for github entries.
    private static func fetchCarthageLatest(for dependency: Dependency) async -> String? {
        let name = dependency.name
        // Carthage github format: "User/Repo"
        guard name.contains("/") else { return nil }
        return await fetchGithubLatestRelease(ownerRepo: name)
    }

    /// Calls the GitHub Releases API and returns the latest stable tag version.
    /// Falls back to the Tags API for repos that don't use formal GitHub Releases.
    private static func fetchGithubLatestRelease(ownerRepo: String) async -> String? {
        guard let url = URL(string: "https://api.github.com/repos/\(ownerRepo)/releases/latest") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("DevAtlasMac/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let version = await fetchRequest(request: request, parse: { data in
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let tag = json?["tag_name"] as? String else { return nil }
            let draft = json?["draft"] as? Bool ?? false
            let prerelease = json?["prerelease"] as? Bool ?? false
            guard !draft, !prerelease else { return nil }
            // Strip leading "v" prefix so "v1.2.3" becomes "1.2.3"
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            return isPreRelease(version) ? nil : version
        }) {
            return version
        }
        // Fallback: many Swift packages use tags only, without formal GitHub Releases
        return await fetchGithubLatestTag(ownerRepo: ownerRepo)
    }

    /// Fetches the latest stable semver tag from the GitHub Tags API.
    private static func fetchGithubLatestTag(ownerRepo: String) async -> String? {
        guard let url = URL(string: "https://api.github.com/repos/\(ownerRepo)/tags?per_page=20") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("DevAtlasMac/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        return await fetchRequest(request: request) { data in
            guard let tags = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
            // Tags are returned newest-first; pick the first stable semver-looking tag
            for tag in tags {
                guard let name = tag["name"] as? String else { continue }
                let version = name.hasPrefix("v") ? String(name.dropFirst()) : name
                if looksLikeSemVer(version) && !isPreRelease(version) {
                    return version
                }
            }
            return nil
        }
    }

    /// Returns true if the string looks like a semver version (e.g. "1.2.3", "10.0").
    private static func looksLikeSemVer(_ version: String) -> Bool {
        let parts = version.components(separatedBy: ".")
        return parts.count >= 2 && parts[0].allSatisfy(\.isNumber) && parts[1].allSatisfy(\.isNumber)
    }

    /// Extracts "owner/repo" from a GitHub URL.
    private static func githubOwnerRepo(from url: String) -> String? {
        // https://github.com/owner/repo.git  OR  https://github.com/owner/repo
        guard url.contains("github.com") else { return nil }
        let cleaned = url
            .replacingOccurrences(of: ".git", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = cleaned.components(separatedBy: "/")
        guard parts.count >= 2 else { return nil }
        return "\(parts[parts.count - 2])/\(parts[parts.count - 1])"
    }

    // MARK: - Pre-release Filter
    
    /// Returns true if the version string is a pre-release (alpha, beta, rc, preview, etc.)
    private static func isPreRelease(_ version: String) -> Bool {
        let lower = version.lowercased()
        let preReleaseIndicators = [
            "alpha", "beta", "rc", "preview", "pre",
            "dev", "next", "canary", "nightly", "snapshot",
            "unstable", "experimental", "milestone", "-m"
        ]
        return preReleaseIndicators.contains { lower.contains($0) }
    }
    
    // MARK: - Generic HTTP Fetch
    
    private static func fetch(url: URL, parse: @escaping (Data) throws -> String?) async -> String? {
        let request = URLRequest(url: url)
        return await fetchRequest(request: request, parse: parse)
    }
    
    private static func fetchRequest(request: URLRequest, parse: @escaping (Data) throws -> String?) async -> String? {
        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 8
            config.timeoutIntervalForResource = 15
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else { return nil }
            return try parse(data)
        } catch {
            return nil
        }
    }
}
