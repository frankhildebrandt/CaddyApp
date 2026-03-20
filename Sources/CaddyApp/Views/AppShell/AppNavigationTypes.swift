import Foundation

enum AppSidebarTab: String, CaseIterable, Identifiable {
    case overview
    case setupStatus = "setup_status"
    case routing
    case services
    case apps
    case monitoring

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Übersicht"
        case .setupStatus: return "Setup & Status"
        case .routing: return "Routing"
        case .services: return "Services"
        case .apps: return "Apps"
        case .monitoring: return "Monitoring"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: return "sparkles.rectangle.stack"
        case .setupStatus: return "checkmark.shield"
        case .routing: return "arrow.triangle.branch"
        case .services: return "shippingbox"
        case .apps: return "bolt.badge.clock"
        case .monitoring: return "waveform.path.ecg"
        }
    }
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case appBehavior = "app_behavior"
    case repositorySync = "repository_sync"
    case routing
    case apps
    case services

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appBehavior: return "App-Verhalten"
        case .repositorySync: return "Feed Sync"
        case .routing: return "Routing"
        case .apps: return "Apps"
        case .services: return "Services"
        }
    }

    var systemImage: String {
        switch self {
        case .appBehavior: return "gearshape"
        case .repositorySync: return "arrow.trianglehead.2.clockwise"
        case .routing: return "arrow.triangle.branch"
        case .apps: return "bolt.badge.clock"
        case .services: return "shippingbox"
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
