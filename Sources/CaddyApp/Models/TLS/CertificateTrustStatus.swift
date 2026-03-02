import Foundation

enum CertificateTrustStatus: String {
    case trusted
    case notTrusted = "not_trusted"
    case notChecked = "not_checked"
    case unknown

    var label: String {
        switch self {
        case .trusted: return "Trusted"
        case .notTrusted: return "Not Trusted"
        case .notChecked: return "Not Checked"
        case .unknown: return "Unknown"
        }
    }
}
