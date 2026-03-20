import Foundation

struct MultipassServiceAssistantDraft: Hashable {
    var vmName: String = ""
    var serviceName: String = ""
    var targetPort: Int = 8080
    var scheme: MultipassServiceScheme = .http
    var systemdUnit: String = ""
    var autoStartVM: Bool = true
    var autoStopVM: Bool = true
    var autoStartSystemd: Bool = true
    var autoStopSystemd: Bool = false
    var idleTimeoutSeconds: Int = 600

    var suggestedHost: String {
        let normalizedServiceName = DNSLabel.normalize(serviceName.trimmingCharacters(in: .whitespacesAndNewlines)) ?? "service"
        let normalizedVMName = DNSLabel.normalize(vmName.trimmingCharacters(in: .whitespacesAndNewlines)) ?? "vm"
        return "\(normalizedServiceName).\(normalizedVMName).mp.localhost"
    }

    var assistantHint: String {
        if vmName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Wähle zuerst eine laufende oder bekannte VM."
        }
        if serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Der Assistent ergänzt den Host automatisch, sobald ein Service-Name gesetzt ist."
        }
        return "Vorschlag: \(suggestedHost) via \(scheme.rawValue.uppercased()) auf Port \(targetPort)."
    }

    func makeService(existingServices: [MultipassServiceDraft]) -> MultipassServiceDraft {
        var draft = MultipassServiceDraft.defaultForVM(vmName, existingServices: existingServices)
        draft.serviceName = serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? draft.serviceName
            : serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.host = suggestedHost
        draft.targetPort = targetPort
        draft.scheme = scheme
        draft.systemdUnit = systemdUnit.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.autoStartVM = autoStartVM
        draft.autoStopVM = autoStopVM
        draft.autoStartSystemd = autoStartSystemd
        draft.autoStopSystemd = autoStopSystemd
        draft.idleTimeoutSeconds = idleTimeoutSeconds
        return draft.normalized()
    }
}
