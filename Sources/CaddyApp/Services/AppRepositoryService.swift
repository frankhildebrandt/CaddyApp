import Foundation
import Yams

actor AppRepositoryService {
    private struct DocumentProbe: Decodable {
        var kind: String
    }

    private struct RepositoryIndexDocument: Decodable {
        struct Spec: Decodable {
            struct Repository: Decodable {
                var id: String?
                var name: String?
                var baseUrl: String?
                var indexUrl: String
                var sourceUrl: String?
                var enabled: Bool?
            }

            var repositories: [Repository]
        }

        var spec: Spec
    }

    private struct AppIndexDocument: Decodable {
        struct Spec: Decodable {
            struct Item: Decodable {
                var key: String?
                var url: String
            }

            var apps: [Item]
        }

        var spec: Spec
    }

    private struct OnDemandAppDocument: Decodable {
        struct Metadata: Decodable {
            var key: String
            var name: String
            var summary: String
        }

        struct Spec: Decodable {
            var runtime: ContainerRuntimeKind
            var unitKind: ContainerUnitKind
            var unitName: String
            var host: String
            var targetHost: String
            var targetPort: Int
            var idleTimeoutSeconds: Int
            var enabled: Bool
            var startMode: OnDemandStartMode
            var runArguments: String?
            var runSteps: [String]?
            var healthPath: String
        }

        var metadata: Metadata
        var spec: Spec
    }

    private struct IndexedPreset: Hashable {
        var sourceKey: String
        var preset: OnDemandAppPreset
    }

    private let decoder = YAMLDecoder()

    func syncPresets(from repositories: [AppRepositoryDraft]) async -> AppRepositorySyncResultWithPresets {
        let enabledRepositories = repositories
            .map(normalizeRepository)
            .filter { $0.enabled && !$0.entryURL.isEmpty }
        guard !enabledRepositories.isEmpty else {
            return AppRepositorySyncResultWithPresets(
                result: AppRepositorySyncResult(
                    succeeded: false,
                    message: "Keine aktiven Repository-URLs konfiguriert.",
                    warnings: [],
                    loadedPresetCount: 0,
                    loadedRepositoryCount: 0,
                    performedAt: Date()
                ),
                presets: []
            )
        }

        var warnings: [String] = []
        var indexedPresets: [IndexedPreset] = []
        var loadedRepositoryCount = 0

        for configuredRepository in enabledRepositories {
            guard let entryURL = URL(string: configuredRepository.entryURL) else {
                warnings.append("Ungültige Repository-URL: \(configuredRepository.entryURL)")
                continue
            }

            do {
                let rootYAML = try await fetchYAML(from: entryURL)
                let rootKind = try parseKind(from: rootYAML)
                switch rootKind.lowercased() {
                case "repositoryindex":
                    let repositoryIndex = try decoder.decode(RepositoryIndexDocument.self, from: rootYAML)
                    for repository in repositoryIndex.spec.repositories where repository.enabled ?? true {
                        guard let indexURL = resolveURL(raw: repository.indexUrl, relativeTo: entryURL) else {
                            warnings.append("Repository-Index-URL nicht auflösbar: \(repository.indexUrl)")
                            continue
                        }
                        let sourceName = repository.name ?? configuredRepository.name
                        let fetched = try await fetchAppIndexPresets(indexURL: indexURL, sourceName: sourceName)
                        loadedRepositoryCount += 1
                        indexedPresets.append(contentsOf: fetched)
                    }
                case "appindex":
                    let sourceName = configuredRepository.name
                    let fetched = try await fetchAppIndexPresets(indexURL: entryURL, sourceName: sourceName)
                    loadedRepositoryCount += 1
                    indexedPresets.append(contentsOf: fetched)
                default:
                    warnings.append("Nicht unterstützter YAML-Kind für \(entryURL.absoluteString): \(rootKind)")
                }
            } catch {
                warnings.append("Repository konnte nicht geladen werden (\(configuredRepository.name)): \(error.localizedDescription)")
            }
        }

        var uniqueBySourceAndKey: [String: OnDemandAppPreset] = [:]
        for indexed in indexedPresets {
            uniqueBySourceAndKey["\(indexed.sourceKey)|\(indexed.preset.key)"] = indexed.preset
        }
        let presets = uniqueBySourceAndKey.values.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }

        let message: String
        let succeeded = !presets.isEmpty
        if succeeded {
            message = "Repository-Update erfolgreich: \(presets.count) Presets aus \(loadedRepositoryCount) Repository-Index(en) geladen."
        } else {
            message = warnings.isEmpty
                ? "Keine Presets gefunden."
                : "Repository-Update ohne importierbare Presets abgeschlossen."
        }

        return AppRepositorySyncResultWithPresets(
            result: AppRepositorySyncResult(
                succeeded: succeeded,
                message: message,
                warnings: warnings,
                loadedPresetCount: presets.count,
                loadedRepositoryCount: loadedRepositoryCount,
                performedAt: Date()
            ),
            presets: presets
        )
    }

    private func fetchAppIndexPresets(indexURL: URL, sourceName: String) async throws -> [IndexedPreset] {
        let yaml = try await fetchYAML(from: indexURL)
        let document = try decoder.decode(AppIndexDocument.self, from: yaml)
        var presets: [IndexedPreset] = []

        for app in document.spec.apps {
            guard let appURL = resolveURL(raw: app.url, relativeTo: indexURL) else { continue }
            do {
                let appYAML = try await fetchYAML(from: appURL)
                let appDocument = try decoder.decode(OnDemandAppDocument.self, from: appYAML)
                guard validate(appDocument.spec) else { continue }

                let preset = OnDemandAppPreset(
                    key: appDocument.metadata.key,
                    title: appDocument.metadata.name,
                    iconSystemName: iconName(for: appDocument.metadata.key),
                    summary: appDocument.metadata.summary,
                    app: OnDemandAppDraft(
                        name: appDocument.metadata.name,
                        runtime: appDocument.spec.runtime,
                        unitKind: appDocument.spec.unitKind,
                        unitName: appDocument.spec.unitName,
                        host: appDocument.spec.host,
                        targetHost: appDocument.spec.targetHost,
                        targetPort: appDocument.spec.targetPort,
                        idleTimeoutSeconds: appDocument.spec.idleTimeoutSeconds,
                        enabled: appDocument.spec.enabled,
                        startMode: appDocument.spec.startMode,
                        runArguments: appDocument.spec.runArguments ?? "",
                        runSteps: appDocument.spec.runSteps ?? [],
                        healthPath: appDocument.spec.healthPath
                    ),
                    notes: "Quelle: \(sourceName) (\(appURL.absoluteString))"
                )
                presets.append(
                    IndexedPreset(
                        sourceKey: sourceName.lowercased(),
                        preset: preset
                    )
                )
            } catch {
                continue
            }
        }

        return presets
    }

    private func fetchYAML(from url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AppRepositoryService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ungültige HTTP-Antwort"])
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "AppRepositoryService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]
            )
        }
        guard let string = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "AppRepositoryService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Antwort ist kein UTF-8 YAML"]
            )
        }
        return string
    }

    private func parseKind(from yaml: String) throws -> String {
        let probe = try decoder.decode(DocumentProbe.self, from: yaml)
        return probe.kind
    }

    private func resolveURL(raw: String, relativeTo baseURL: URL) -> URL? {
        if let absolute = URL(string: raw), absolute.scheme != nil {
            return absolute
        }
        return URL(string: raw, relativeTo: baseURL)?.absoluteURL
    }

    private func normalizeRepository(_ repository: AppRepositoryDraft) -> AppRepositoryDraft {
        var normalized = repository
        normalized.name = repository.name.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized.entryURL = repository.entryURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized
    }

    private func validate(_ spec: OnDemandAppDocument.Spec) -> Bool {
        if spec.unitName.isEmpty || spec.host.isEmpty || spec.targetHost.isEmpty {
            return false
        }
        if spec.targetPort <= 0 || spec.targetPort > 65535 {
            return false
        }
        if spec.idleTimeoutSeconds < 15 {
            return false
        }
        if spec.runtime == .docker && spec.unitKind == .pod {
            return false
        }
        if spec.startMode == .runCommand {
            let hasRunArguments = !(spec.runArguments?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            let hasRunSteps = !(spec.runSteps ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.isEmpty
            if !hasRunArguments, !hasRunSteps {
                return false
            }
        }
        return true
    }

    private func iconName(for key: String) -> String {
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
        default:
            return "shippingbox"
        }
    }
}

struct AppRepositorySyncResultWithPresets {
    var result: AppRepositorySyncResult
    var presets: [OnDemandAppPreset]
}
