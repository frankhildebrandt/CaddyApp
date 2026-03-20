import Foundation

@MainActor
final class MultipassViewModel: ObservableObject {
    @Published var assistant = MultipassServiceAssistantDraft()

    let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }()

    func autoHost(for name: String) -> String? {
        let lowered = name.lowercased()
        let mapped = lowered.map { character -> Character in
            if character.isLetter || character.isNumber || character == "-" {
                return character
            }
            return "-"
        }
        let label = String(mapped)
            .replacingOccurrences(of: "--+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        guard !label.isEmpty else { return nil }
        let truncated = String(label.prefix(63))
        return "\(truncated).mp.localhost"
    }

    func prepareAssistant(defaultVMName: String?, existingServices: [MultipassServiceDraft]) {
        if let defaultVMName, assistant.vmName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            assistant.vmName = defaultVMName
        }
        if assistant.serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let suggested = MultipassServiceDraft.defaultForVM(assistant.vmName, existingServices: existingServices)
            assistant.serviceName = suggested.serviceName
        }
    }

    func commitAssistant(existingServices: [MultipassServiceDraft]) -> MultipassServiceDraft {
        let draft = assistant.makeService(existingServices: existingServices)
        assistant = MultipassServiceAssistantDraft(vmName: assistant.vmName)
        return draft
    }
}
