import Foundation

struct CaddyInstallationService {
    private let shell = ShellCommandRunner()

    func loadStatus() -> CaddyInstallStatus {
        let whichResult = shell.runShell("command -v caddy")
        guard whichResult.isSuccess else {
            return CaddyInstallStatus(
                isInstalled: false,
                version: nil,
                binaryPath: nil,
                suggestedInstallCommand: "brew install caddy"
            )
        }

        let path = whichResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let versionResult = shell.runShell("caddy version")
        let version = versionResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

        return CaddyInstallStatus(
            isInstalled: true,
            version: version.isEmpty ? nil : version,
            binaryPath: path,
            suggestedInstallCommand: path == AppPaths.managedCaddyBinary.path
                ? "CaddyApp managed binary update (use 'Update Caddy')"
                : "brew upgrade caddy"
        )
    }

    func isUpdateAvailable(localVersion: String?, latestTag: String?) -> Bool {
        guard let localVersion, let latestTag else { return false }
        return compareSemver(normalize(localVersion), normalize(latestTag)) == .orderedAscending
    }

    func updateViaHomebrew() -> CaddyUpdateOperationResult {
        let before = loadStatus()
        let beforeVersion = before.version
        let usingManagedBinary = before.binaryPath == AppPaths.managedCaddyBinary.path

        if usingManagedBinary {
            return directDownloadUpdateResult(previousVersion: beforeVersion)
        }

        let brewCheck = shell.runShell("command -v brew")
        guard brewCheck.isSuccess else {
            return directDownloadUpdateResult(previousVersion: beforeVersion)
        }

        let upgradeResult = shell.runShell("brew update --quiet && brew upgrade caddy")
        if upgradeResult.isSuccess {
            let after = loadStatus()
            return CaddyUpdateOperationResult(
                succeeded: true,
                message: "Caddy update completed",
                output: combinedOutput(upgradeResult),
                previousVersion: beforeVersion,
                currentVersion: after.version,
                recoveryAttempted: false,
                recoverySucceeded: nil,
                performedAt: Date()
            )
        }

        // Recovery fallback for broken/incomplete Homebrew state after failed upgrade.
        let recoveryResult = shell.runShell("brew reinstall caddy")
        let after = loadStatus()
        let recoverySucceeded = recoveryResult.isSuccess && after.isInstalled
        let combined = [combinedOutput(upgradeResult), combinedOutput(recoveryResult)]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n--- recovery (brew reinstall caddy) ---\n\n")

        return CaddyUpdateOperationResult(
            succeeded: false,
            message: recoverySucceeded
                ? "Caddy update failed, but installation was recovered via brew reinstall"
                : "Caddy update failed and recovery attempt did not succeed",
            output: combined,
            previousVersion: beforeVersion,
            currentVersion: after.version,
            recoveryAttempted: true,
            recoverySucceeded: recoverySucceeded,
            performedAt: Date()
        )
    }

    func installForBootstrap() -> SetupOperationResult {
        let brewCheck = shell.runShell("command -v brew")
        var attempts: [String] = []

        if brewCheck.isSuccess {
            let brewInstall = shell.runShell("brew install caddy")
            let brewOutput = combinedOutput(brewInstall)
            if !brewOutput.isEmpty { attempts.append(brewOutput) }
            if brewInstall.isSuccess {
                return SetupOperationResult(
                    kind: .installCaddy,
                    succeeded: true,
                    message: "Caddy installed via Homebrew",
                    output: brewOutput,
                    performedAt: Date()
                )
            }
        }

        let direct = installManagedBinaryFromGitHub()
        let directOutput = [attempts.joined(separator: "\n\n"), direct.output]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n--- direct download fallback ---\n\n")
        return SetupOperationResult(
            kind: .installCaddy,
            succeeded: direct.succeeded,
            message: direct.message,
            output: directOutput,
            performedAt: Date()
        )
    }

    private func combinedOutput(_ result: CommandResult) -> String {
        [result.stdout.trimmingCharacters(in: .whitespacesAndNewlines), result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private func directDownloadUpdateResult(previousVersion: String?) -> CaddyUpdateOperationResult {
        let direct = installManagedBinaryFromGitHub()
        let after = loadStatus()
        return CaddyUpdateOperationResult(
            succeeded: direct.succeeded,
            message: direct.succeeded
                ? "Caddy updated via direct download (app-managed binary)"
                : "Direct-download Caddy update failed",
            output: direct.output,
            previousVersion: previousVersion,
            currentVersion: after.version,
            recoveryAttempted: false,
            recoverySucceeded: nil,
            performedAt: Date()
        )
    }

    private func installManagedBinaryFromGitHub() -> (succeeded: Bool, message: String, output: String) {
        let managedBin = AppPaths.managedBinDirectory.path
        let managedCaddy = AppPaths.managedCaddyBinary.path
        let escapedManagedBin = managedBin.replacingOccurrences(of: "'", with: "'\\''")
        let escapedManagedCaddy = managedCaddy.replacingOccurrences(of: "'", with: "'\\''")

        let script = """
        set -euo pipefail
        arch_raw="$(uname -m)"
        case "$arch_raw" in
          arm64) caddy_arch="arm64" ;;
          x86_64) caddy_arch="amd64" ;;
          *) echo "Unsupported macOS architecture: $arch_raw" >&2; exit 1 ;;
        esac

        api_json="$(curl -fsSL https://api.github.com/repos/caddyserver/caddy/releases/latest)"
        tag="$(printf '%s' "$api_json" | sed -nE 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\\1/p' | head -n1)"
        if [ -z "$tag" ]; then
          echo "Could not parse latest Caddy tag from GitHub API" >&2
          exit 1
        fi

        ver="${tag#v}"
        url="https://github.com/caddyserver/caddy/releases/download/${tag}/caddy_${ver}_mac_${caddy_arch}.tar.gz"

        tmpdir="$(mktemp -d)"
        trap 'rm -rf "$tmpdir"' EXIT
        curl -fL "$url" -o "$tmpdir/caddy.tar.gz"
        tar -xzf "$tmpdir/caddy.tar.gz" -C "$tmpdir"

        mkdir -p '\(escapedManagedBin)'
        install -m 0755 "$tmpdir/caddy" '\(escapedManagedCaddy)'
        echo "Installed Caddy to \(managedCaddy)"
        """

        let result = shell.runShell(script)
        let output = combinedOutput(result)
        return (
            succeeded: result.isSuccess,
            message: result.isSuccess
                ? "Caddy installed via direct GitHub release download to app-managed bin"
                : "Direct Caddy download/install failed",
            output: output
        )
    }

    private func normalize(_ value: String) -> [Int] {
        let cleaned = value.lowercased()
            .replacingOccurrences(of: "v", with: "")
            .components(separatedBy: CharacterSet(charactersIn: "0123456789." ).inverted)
            .joined()
        return cleaned.split(separator: ".").compactMap { Int($0) }
    }

    private func compareSemver(_ lhs: [Int], _ rhs: [Int]) -> ComparisonResult {
        let maxCount = max(lhs.count, rhs.count)
        for idx in 0..<maxCount {
            let left = idx < lhs.count ? lhs[idx] : 0
            let right = idx < rhs.count ? rhs[idx] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }
}
