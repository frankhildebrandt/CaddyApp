import Foundation

struct AppGeneralSettings: Codable, Hashable {
    var hideWindowToMenuBarOnClose: Bool

    static let `default` = AppGeneralSettings(hideWindowToMenuBarOnClose: false)
}

struct AppRoutingSettings: Codable, Hashable {
    var enableTraefikMeAliases: Bool
    var additionalCaddyfileConfig: String

    static let `default` = AppRoutingSettings(
        enableTraefikMeAliases: true,
        additionalCaddyfileConfig: ""
    )
}

struct AppRepositorySyncSettings: Codable, Hashable {
    var autoUpdateEnabled: Bool
    var autoUpdateIntervalHours: Int
    var lastSuccessfulSyncAt: Date?
    var lastSyncError: String?
    var lastLoadedPresetCount: Int
    var lastLoadedRepositoryCount: Int

    static let `default` = AppRepositorySyncSettings(
        autoUpdateEnabled: true,
        autoUpdateIntervalHours: 6,
        lastSuccessfulSyncAt: nil,
        lastSyncError: nil,
        lastLoadedPresetCount: 0,
        lastLoadedRepositoryCount: 0
    )

    var sanitized: AppRepositorySyncSettings {
        var sanitized = self
        sanitized.autoUpdateIntervalHours = min(max(autoUpdateIntervalHours, 1), 24)
        sanitized.lastSyncError = lastSyncError?.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized
    }
}

struct AppConfig: Codable, Hashable {
    var general: AppGeneralSettings
    var routing: AppRoutingSettings
    var repositorySync: AppRepositorySyncSettings
    var customRoutes: [CustomRouteDraft]
    var onDemandApps: [OnDemandAppDraft]
    var multipassServices: [MultipassServiceDraft]
    var appRepositories: [AppRepositoryDraft]

    static let `default` = AppConfig(
        general: .default,
        routing: .default,
        repositorySync: .default,
        customRoutes: [
            CustomRouteDraft(host: "app.localhost", upstream: "127.0.0.1:3000", enabled: true),
            CustomRouteDraft(host: "api.localhost", upstream: "127.0.0.1:8080", enabled: true)
        ],
        onDemandApps: [],
        multipassServices: [],
        appRepositories: AppRepositoryDraft.defaultList
    )

    var enableTraefikMeAliases: Bool {
        get { routing.enableTraefikMeAliases }
        set { routing.enableTraefikMeAliases = newValue }
    }

    var additionalCaddyfileConfig: String {
        get { routing.additionalCaddyfileConfig }
        set { routing.additionalCaddyfileConfig = newValue }
    }

    init(
        general: AppGeneralSettings,
        routing: AppRoutingSettings,
        repositorySync: AppRepositorySyncSettings,
        customRoutes: [CustomRouteDraft],
        onDemandApps: [OnDemandAppDraft],
        multipassServices: [MultipassServiceDraft],
        appRepositories: [AppRepositoryDraft]
    ) {
        self.general = general
        self.routing = routing
        self.repositorySync = repositorySync.sanitized
        self.customRoutes = customRoutes
        self.onDemandApps = onDemandApps
        self.multipassServices = multipassServices
        self.appRepositories = appRepositories
    }
}

struct CustomConfigSettings: Codable, Hashable {
    var customRoutes: [CustomRouteDraft]
    var onDemandApps: [OnDemandAppDraft]
    var multipassServices: [MultipassServiceDraft]
    var appRepositories: [AppRepositoryDraft]
    var enableTraefikMeAliases: Bool
    var additionalCaddyfileConfig: String

    static let `default` = CustomConfigSettings(
        customRoutes: AppConfig.default.customRoutes,
        onDemandApps: AppConfig.default.onDemandApps,
        multipassServices: AppConfig.default.multipassServices,
        appRepositories: AppConfig.default.appRepositories,
        enableTraefikMeAliases: AppConfig.default.enableTraefikMeAliases,
        additionalCaddyfileConfig: AppConfig.default.additionalCaddyfileConfig
    )
}

extension AppConfig {
    init(legacy settings: CustomConfigSettings) {
        self.init(
            general: .default,
            routing: AppRoutingSettings(
                enableTraefikMeAliases: settings.enableTraefikMeAliases,
                additionalCaddyfileConfig: settings.additionalCaddyfileConfig
            ),
            repositorySync: .default,
            customRoutes: settings.customRoutes,
            onDemandApps: settings.onDemandApps,
            multipassServices: settings.multipassServices,
            appRepositories: settings.appRepositories
        )
    }
}
