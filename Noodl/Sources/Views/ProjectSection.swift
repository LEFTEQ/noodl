import SwiftUI

struct ProjectSection: View {
    let project: TodoProject
    var store: TodoStore
    @State private var isExpanded: Bool

    init(project: TodoProject, store: TodoStore) {
        self.project = project
        self.store = store
        // Expand by default if there are open items
        self._isExpanded = State(initialValue: project.openCount > 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 10)

                    Text(project.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    if project.openCount > 0 {
                        Text("\(project.openCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Items
            if isExpanded {
                let openItems = project.items.filter { !$0.isDone }
                let doneItems = project.items.filter { $0.isDone }

                ForEach(openItems) { item in
                    TodoRow(item: item, project: project, store: store)
                }

                if !doneItems.isEmpty {
                    ForEach(doneItems) { item in
                        TodoRow(item: item, project: project, store: store)
                    }
                }
            }
        }
    }
}
