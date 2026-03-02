import Foundation

struct FeatureItem: Identifiable {
    let id: String
    let title: String
    let status: FeatureStatus
    let summary: String
    let documentPath: String
}
