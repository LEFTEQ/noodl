import SwiftUI

struct SectionHeader: View {
    let section: NoodlSection
    let title: String
    let count: Int
    @Binding var isCollapsed: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                isCollapsed.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: section.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.secondary)

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
