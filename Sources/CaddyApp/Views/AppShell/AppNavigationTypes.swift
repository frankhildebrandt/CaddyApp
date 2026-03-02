import Foundation

enum AppSidebarTab: String, CaseIterable, Identifiable {
    case dashboard
    case caddyTLS = "caddy_tls"
    case runtime
    case config
    case logs
    case features

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .caddyTLS: return "Caddy & TLS"
        case .runtime: return "Runtime"
        case .config: return "Config"
        case .logs: return "Logging"
        case .features: return "Features"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "rectangle.grid.2x2"
        case .caddyTLS: return "lock.shield"
        case .runtime: return "server.rack"
        case .config: return "doc.text"
        case .logs: return "terminal"
        case .features: return "list.bullet.clipboard"
        }
    }
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case onDemandApps = "on_demand_apps"
    case services
    case customConfig = "custom_config"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "Allgemein"
        case .onDemandApps: return "On-Demand Apps"
        case .services: return "Services"
        case .customConfig: return "Custom Config"
        }
    }

    var systemImage: String {
        switch self {
        case .general: return "gearshape"
        case .onDemandApps: return "bolt.badge.clock"
        case .services: return "shippingbox"
        case .customConfig: return "slider.horizontal.3"
        }
    }
}

enum OnDemandSubTab: String, CaseIterable, Identifiable {
    case config
    case hostLog = "host_log"
    case containerLog = "container_log"
    case shell
    case eventLog = "event_log"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .config: return "Config"
        case .hostLog: return "Host-Log"
        case .containerLog: return "Container/Pod-Log"
        case .shell: return "Shell"
        case .eventLog: return "Eventlog"
        }
    }
}
