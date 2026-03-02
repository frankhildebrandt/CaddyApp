import Foundation

struct RuntimeTarget: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var source: RuntimeSource
    var address: String
    var status: String
}
