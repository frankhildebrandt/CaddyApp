import Foundation

struct OnDemandAppPreset: Identifiable, Hashable {
    var id: String { key }
    var key: String
    var title: String
    var iconSystemName: String
    var summary: String
    var app: OnDemandAppDraft
    var notes: String
}
