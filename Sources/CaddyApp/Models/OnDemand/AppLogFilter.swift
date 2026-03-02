import Foundation

enum AppLogFilter {
    static func filter(_ raw: String, containsAny needles: [String]) -> String {
        raw
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { line in
                let lowered = line.lowercased()
                return needles.contains(where: { !$0.isEmpty && lowered.contains($0) })
            }
            .joined(separator: "\n")
    }
}
