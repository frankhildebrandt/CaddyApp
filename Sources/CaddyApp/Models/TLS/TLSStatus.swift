import Foundation

struct TLSStatus {
    var localCARootPath: String
    var rootCertificatePresent: Bool
    var systemKeychainTrustStatus: CertificateTrustStatus
    var systemKeychainTrustDetails: String
    var caddyTrustCommand: String
    var installHint: String
}
