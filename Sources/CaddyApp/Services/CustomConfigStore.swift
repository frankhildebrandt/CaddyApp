import Foundation

struct CustomConfigStore {
    private let fileManager = FileManager.default
    private let fileURL = AppPaths.appSupportDirectory.appendingPathComponent("custom-config.json", isDirectory: false)

    func load() -> CustomConfigSettings {
        guard let data = try? Data(contentsOf: fileURL) else {
            return .default
        }

        do {
            let settings = try JSONDecoder().decode(CustomConfigSettings.self, from: data)
            return sanitized(settings)
        } catch {
            return .default
        }
    }

    func save(_ settings: CustomConfigSettings) throws {
        try fileManager.createDirectory(at: AppPaths.appSupportDirectory, withIntermediateDirectories: true)
        let data = try JSONEncoder.pretty.encode(sanitized(settings))
        try data.write(to: fileURL, options: .atomic)
    }

    private func sanitized(_ settings: CustomConfigSettings) -> CustomConfigSettings {
        CustomConfigSettings(
            customRoutes: settings.customRoutes,
            onDemandApps: settings.onDemandApps,
            multipassServices: settings.multipassServices,
            appRepositories: settings.appRepositories,
            enableTraefikMeAliases: settings.enableTraefikMeAliases,
            additionalCaddyfileConfig: settings.additionalCaddyfileConfig
        )
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
