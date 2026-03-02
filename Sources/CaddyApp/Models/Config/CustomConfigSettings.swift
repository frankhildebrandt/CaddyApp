import Foundation

struct CustomConfigSettings: Codable {
    var customRoutes: [CustomRouteDraft]
    var onDemandApps: [OnDemandAppDraft]
    var multipassServices: [MultipassServiceDraft]
    var appRepositories: [AppRepositoryDraft]
    var enableTraefikMeAliases: Bool
    var additionalCaddyfileConfig: String

    static let `default` = CustomConfigSettings(
        customRoutes: [
            CustomRouteDraft(host: "app.localhost", upstream: "127.0.0.1:3000", enabled: true),
            CustomRouteDraft(host: "api.localhost", upstream: "127.0.0.1:8080", enabled: true)
        ],
        onDemandApps: [],
        multipassServices: [],
        appRepositories: AppRepositoryDraft.defaultList,
        enableTraefikMeAliases: true,
        additionalCaddyfileConfig: ""
    )

    enum CodingKeys: String, CodingKey {
        case customRoutes
        case onDemandApps
        case multipassServices
        case appRepositories
        case enableTraefikMeAliases
        case additionalCaddyfileConfig
    }

    init(
        customRoutes: [CustomRouteDraft],
        onDemandApps: [OnDemandAppDraft],
        multipassServices: [MultipassServiceDraft],
        appRepositories: [AppRepositoryDraft],
        enableTraefikMeAliases: Bool,
        additionalCaddyfileConfig: String
    ) {
        self.customRoutes = customRoutes
        self.onDemandApps = onDemandApps
        self.multipassServices = multipassServices
        self.appRepositories = appRepositories
        self.enableTraefikMeAliases = enableTraefikMeAliases
        self.additionalCaddyfileConfig = additionalCaddyfileConfig
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        customRoutes = try container.decodeIfPresent([CustomRouteDraft].self, forKey: .customRoutes)
            ?? Self.default.customRoutes
        onDemandApps = try container.decodeIfPresent([OnDemandAppDraft].self, forKey: .onDemandApps)
            ?? Self.default.onDemandApps
        multipassServices = try container.decodeIfPresent([MultipassServiceDraft].self, forKey: .multipassServices)
            ?? Self.default.multipassServices
        appRepositories = try container.decodeIfPresent([AppRepositoryDraft].self, forKey: .appRepositories)
            ?? AppRepositoryDraft.defaultList
        enableTraefikMeAliases = try container.decodeIfPresent(Bool.self, forKey: .enableTraefikMeAliases)
            ?? Self.default.enableTraefikMeAliases
        additionalCaddyfileConfig = try container.decodeIfPresent(String.self, forKey: .additionalCaddyfileConfig)
            ?? Self.default.additionalCaddyfileConfig
    }
}
