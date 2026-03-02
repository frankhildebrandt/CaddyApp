import Foundation

enum SetupOperationKind: String {
    case installCaddy = "install_caddy"
    case generateLocalCA = "generate_local_ca"
    case trustLocalCA = "trust_local_ca"
    case repairHomebrewService = "repair_homebrew_service"
    case consolidateCaddyInstances = "consolidate_caddy_instances"
}
