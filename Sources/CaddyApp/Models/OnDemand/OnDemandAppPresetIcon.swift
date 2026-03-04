import Foundation

enum OnDemandAppPresetIcon {
    static func forKey(_ key: String) -> String {
        switch key.lowercased() {
        case "loki":
            return "text.alignleft"
        case "grafana":
            return "chart.xyaxis.line"
        case "kimai":
            return "clock.badge.checkmark"
        case "ephe":
            return "doc.text.magnifyingglass"
        case "penpot":
            return "pencil.and.ruler"
        case "authentik":
            return "person.badge.shield.checkmark"
        default:
            return "shippingbox"
        }
    }
}
