import Foundation

struct QuickCommand: Identifiable, Hashable {
    let id: UUID
    let title: String
    let command: String
    let kind: Kind

    enum Kind: String {
        case shell
        case ai
    }

    init(id: UUID = UUID(), title: String, command: String, kind: Kind) {
        self.id = id
        self.title = title
        self.command = command
        self.kind = kind
    }
}
