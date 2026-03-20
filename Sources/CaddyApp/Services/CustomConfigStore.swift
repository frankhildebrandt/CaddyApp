import Foundation

struct AppConfigStore {
    private let fileManager = FileManager.default
    private let fileURL = AppPaths.appSupportDirectory.appendingPathComponent("custom-config.json", isDirectory: false)

    func load() -> AppConfig {
        guard let data = try? Data(contentsOf: fileURL) else {
            return .default
        }

        do {
            let config = try JSONDecoder().decode(AppConfig.self, from: data)
            return sanitized(config)
        } catch {
            do {
                let legacy = try JSONDecoder().decode(CustomConfigSettings.self, from: data)
                return sanitized(AppConfig(legacy: legacy))
            } catch {
                return .default
            }
        }
    }

    func save(_ config: AppConfig) throws {
        try fileManager.createDirectory(at: AppPaths.appSupportDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder.pretty.encode(sanitized(config))
        try data.write(to: fileURL, options: .atomic)
    }

    private func sanitized(_ config: AppConfig) -> AppConfig {
        AppConfig(
            general: config.general,
            routing: config.routing,
            repositorySync: config.repositorySync.sanitized,
            customRoutes: config.customRoutes,
            onDemandApps: config.onDemandApps,
            multipassServices: config.multipassServices,
            appRepositories: config.appRepositories
        )
    }
}

typealias CustomConfigStore = AppConfigStore

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
