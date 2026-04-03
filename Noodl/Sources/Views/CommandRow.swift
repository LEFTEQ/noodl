import SwiftUI
import AppKit

struct CommandRow: View {
    let command: QuickCommand
    @State private var isRunning = false
    @State private var result: CommandRunner.Result?
    @State private var showResult = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                guard !isRunning else { return }
                runCommand()
            } label: {
                HStack(spacing: 8) {
                    // Icon
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: command.kind == .ai ? "sparkles" : "terminal")
                            .font(.system(size: 11))
                            .foregroundStyle(command.kind == .ai ? Color.purple : Color.secondary)
                            .frame(width: 14)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(command.title)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)

                            if command.kind == .ai {
                                Text("AI")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.purple.opacity(0.15))
                                    .foregroundStyle(.purple)
                                    .clipShape(Capsule())
                            }
                        }

                        Text(command.command)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Spacer()

                    // Status indicator
                    if let result {
                        Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(result.isSuccess ? .green : .red)
                    }
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command.command, forType: .string)
                } label: {
                    Label("Copy command", systemImage: "doc.on.doc")
                }

                if let result {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result.output, forType: .string)
                    } label: {
                        Label("Copy output", systemImage: "doc.on.clipboard")
                    }
                }
            }

            // Result panel
            if showResult, let result {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(result.isSuccess ? "Success" : "Error (exit \(result.exitCode))")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(result.isSuccess ? .green : .red)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(result.output, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)

                        Button {
                            withAnimation { showResult = false }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }

                    ScrollView {
                        Text(result.output.isEmpty ? "(no output)" : result.output)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.03))
            }
        }
    }

    private func runCommand() {
        isRunning = true
        result = nil
        showResult = false

        Task {
            let res: CommandRunner.Result
            switch command.kind {
            case .shell:
                res = await CommandRunner.run(shell: command.command)
            case .ai:
                res = await CommandRunner.runAI(prompt: command.command)
            }

            await MainActor.run {
                result = res
                isRunning = false
                withAnimation { showResult = true }
            }
        }
    }
}
