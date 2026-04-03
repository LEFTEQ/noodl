import SwiftUI

struct MemorySidebar: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Memory")
                    .font(.system(size: 10, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(Date.now, format: .dateTime.day().month().year())
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))

            Divider()

            Spacer()

            VStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 24))
                    .foregroundStyle(.tertiary)
                Text("Screenshots & voice\ncoming soon")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Divider()

            HStack {
                Button {
                } label: {
                    Text("← Yesterday")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Today")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Tomorrow →")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.secondary.opacity(0.3))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }
}
