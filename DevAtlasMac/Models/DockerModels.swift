import Foundation

enum DockerDaemonState: String, Sendable {
    case running, stopped, notInstalled
    var title: String { "docker.daemon.\(rawValue)".localized }
}

struct DockerRuntime: Identifiable, Hashable, Sendable {
    let name: String
    let launchPath: String
    let isCommand: Bool
    var id: String { launchPath }
}

struct DockerPublishedPort: Identifiable, Hashable, Sendable {
    let hostIP: String
    let hostPort: String
    let containerPort: String
    let transport: String
    var id: String { "\(hostIP):\(hostPort):\(containerPort)/\(transport)" }
    var title: String { "\(hostPort) → \(containerPort)/\(transport)" }
    var browserURL: URL? {
        guard transport == "tcp", let port = Int(hostPort),
              [80, 443, 3000, 3001, 4200, 5000, 5173, 8000, 8001, 8080, 8081, 8025, 9000].contains(port) else { return nil }
        return URL(string: "\(port == 443 ? "https" : "http")://localhost:\(port)")
    }
}

struct DockerContainer: Identifiable, Hashable, Sendable {
    var id: String
    var name: String
    var image: String
    var status: String
    var state: String
    var ports: [DockerPublishedPort] = []
    var composeProject: String?
    var workingDirectory: String?
    var bindMounts: [String] = []
    var cpuPercent: Double?
    var memoryBytes: Double?
    var memoryUsage: String?
    var isRunning: Bool { state == "running" }
    var stateTitle: String { "docker.state.\(state)".localized }

    func projectPath(in paths: [String]) -> String? {
        ([workingDirectory].compactMap { $0 } + bindMounts)
            .compactMap { PortProcessService.matchingPath(for: $0, projectPaths: paths) }
            .max { $0.count < $1.count }
    }
}

struct DockerComposeStack: Identifiable, Hashable, Sendable {
    let projectID: String
    let projectName: String
    let fileURL: URL
    var id: String { fileURL.path }
}

enum DockerContainerAction: String, CaseIterable, Sendable {
    case start, stop, restart, remove
    var title: String { "docker.action.\(rawValue)".localized }
    var arguments: [String] { [self == .remove ? "rm" : rawValue] }
}

enum DockerStackAction: String, Sendable {
    case up, down, rebuild
    var title: String { "docker.stack.\(rawValue)".localized }
    var arguments: [String] {
        switch self {
        case .up: ["up", "-d"]
        case .down: ["down"]
        case .rebuild: ["up", "-d", "--build"]
        }
    }
}

struct ComposePortMapping: Identifiable, Equatable, Sendable {
    var id = UUID()
    var host = ""
    var target = ""
    var transport = "tcp"
    var hostIP = ""
    var yaml: String { (hostIP.isEmpty ? "" : hostIP + ":") + (host.isEmpty ? "" : host + ":") + target + "/" + transport }
}

struct ComposeEnvVar: Identifiable, Equatable, Sendable {
    var id = UUID()
    var key = ""
    /// nil means inherit from the host, distinct from an empty string.
    var value: String? = ""
    var isSecret: Bool { ["PASSWORD", "SECRET", "TOKEN", "KEY"].contains { key.uppercased().contains($0) } }
}

struct ComposeVolumeMount: Identifiable, Equatable, Sendable {
    var id = UUID()
    var source = ""
    var target = ""
    var readOnly = false
    var yaml: String { (source.isEmpty ? "" : source + ":") + target + (readOnly ? ":ro" : "") }
    var namedVolume: String? {
        guard !source.isEmpty, source.range(of: "^[A-Za-z0-9][A-Za-z0-9_.-]*$", options: .regularExpression) != nil else { return nil }
        return source
    }
}

struct DockerComposeService: Identifiable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var containerName = ""
    var image = ""
    var useBuild = false
    var buildContext = "."
    var dockerfile = "Dockerfile"
    var restart = ""
    var command = ""
    var workingDirectory = ""
    var ports: [ComposePortMapping] = []
    var environment: [ComposeEnvVar] = []
    var envFiles: [String] = []
    var volumes: [ComposeVolumeMount] = []
    var dependencies: [String] = []
    var networks: [String] = []
    /// Advanced syntax remains in the source; these fields are edited in YAML only.
    var lockedFields: Set<String> = []
}

struct DockerComposeDocument: Sendable {
    var source: String
    var services: [DockerComposeService]
    var originalServices: [DockerComposeService]
    var visualUnavailable: Bool = false
}

enum DockerServiceTemplate: String, CaseIterable, Identifiable {
    case postgres, redis, mysql, mariadb, mongodb, rabbitmq, minio, mailpit, pgadmin, adminer, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .postgres: "PostgreSQL"
        case .redis: "Redis"
        case .mysql: "MySQL"
        case .mariadb: "MariaDB"
        case .mongodb: "MongoDB"
        case .rabbitmq: "RabbitMQ"
        case .minio: "MinIO"
        case .mailpit: "Mailpit"
        case .pgadmin: "pgAdmin"
        case .adminer: "Adminer"
        case .custom: "docker.customService".localized
        }
    }

    func service(named name: String) -> DockerComposeService {
        var service = DockerComposeService(name: name, restart: "unless-stopped")
        func port(_ host: String, _ target: String? = nil) -> ComposePortMapping { .init(host: host, target: target ?? host, hostIP: "127.0.0.1") }
        func env(_ key: String, _ value: String) -> ComposeEnvVar { .init(key: key, value: value) }
        switch self {
        case .postgres:
            service.image = "postgres:16-alpine"; service.ports = [port("5432")]
            service.environment = [env("POSTGRES_DB", "app"), env("POSTGRES_USER", "app"), env("POSTGRES_PASSWORD", "${POSTGRES_PASSWORD:?Set POSTGRES_PASSWORD in .env}")]
            service.volumes = [.init(source: "\(name)_data", target: "/var/lib/postgresql/data")]
        case .redis:
            service.image = "redis:7-alpine"; service.ports = [port("6379")]
            service.volumes = [.init(source: "\(name)_data", target: "/data")]
        case .mysql, .mariadb:
            service.image = self == .mysql ? "mysql:8.4" : "mariadb:11"
            service.ports = [port("3306")]; service.environment = [env("MYSQL_DATABASE", "app"), env("MYSQL_ROOT_PASSWORD", "${MYSQL_ROOT_PASSWORD:?Set MYSQL_ROOT_PASSWORD in .env}")]
            service.volumes = [.init(source: "\(name)_data", target: "/var/lib/mysql")]
        case .mongodb:
            service.image = "mongo:7"; service.ports = [port("27017")]
            service.volumes = [.init(source: "\(name)_data", target: "/data/db")]
        case .rabbitmq:
            service.image = "rabbitmq:3-management-alpine"; service.ports = [port("5672"), port("15672")]
        case .minio:
            service.image = "minio/minio"; service.command = "server /data --console-address :9001"
            service.ports = [port("9000"), port("9001")]
            service.environment = [env("MINIO_ROOT_USER", "appadmin"), env("MINIO_ROOT_PASSWORD", "${MINIO_ROOT_PASSWORD:?Set MINIO_ROOT_PASSWORD in .env}")]
            service.volumes = [.init(source: "\(name)_data", target: "/data")]
        case .mailpit:
            service.image = "axllent/mailpit"; service.ports = [port("8025"), port("1025")]
        case .pgadmin:
            service.image = "dpage/pgadmin4"; service.ports = [port("5050", "80")]
            service.environment = [env("PGADMIN_DEFAULT_EMAIL", "admin@example.com"), env("PGADMIN_DEFAULT_PASSWORD", "${PGADMIN_DEFAULT_PASSWORD:?Set PGADMIN_DEFAULT_PASSWORD in .env}")]
        case .adminer:
            service.image = "adminer:4"; service.ports = [port("8080")]
        case .custom: service.image = "alpine:3"
        }
        return service
    }
}
