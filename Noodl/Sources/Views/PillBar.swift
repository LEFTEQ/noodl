import SwiftUI

enum NoodlSection: String, CaseIterable {
    case todos
    case snippets
    case commands

    var icon: String {
        switch self {
        case .todos: "checkmark.square"
        case .snippets: "doc.on.clipboard"
        case .commands: "bolt"
        }
    }
}

struct PillBar: View {
    let todoCount: Int
    let snippetCount: Int
    let commandCount: Int
    var activeSection: NoodlSection = .todos
    var onTap: (NoodlSection) -> Void

    var body: some View {
        HStack(spacing: 4) {
            pill(.todos, count: todoCount)
            pill(.snippets, count: snippetCount)
            pill(.commands, count: commandCount)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func pill(_ section: NoodlSection, count: Int) -> some View {
        let isActive = activeSection == section
        return Button {
            onTap(section)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: section.icon)
                    .font(.system(size: 9))
                Text("\(count)")
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
