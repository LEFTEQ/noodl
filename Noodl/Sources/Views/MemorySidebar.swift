import SwiftUI
import AppKit

struct MemorySidebar: View {
    var memoryStore: MemoryStore
    var screenshotService: ScreenshotService
    var voiceRecorder: VoiceRecorder

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Memory")
                        .font(.system(size: 10, weight: .medium))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text(memoryStore.displayDate)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if memoryStore.isSummarizing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        memoryStore.summarize()
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11))
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                    .help("AI Summarize")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Summary result
                    if let summary = memoryStore.summaryResult {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("AI Summary")
                                    .font(.system(size: 8, weight: .medium))
                                    .textCase(.uppercase)
                                    .foregroundStyle(.purple)
                                Spacer()
                                Button {
                                    memoryStore.summaryResult = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            Text(summary)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        .padding(8)
                        .background(Color.purple.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                    }

                    // Screenshots
                    HStack {
                        Text("Screenshots")
                            .font(.system(size: 8, weight: .medium))
                            .textCase(.uppercase)
                            .foregroundStyle(.tertiary)
                        if !memoryStore.screenshots.isEmpty {
                            Text("(\(memoryStore.screenshots.count))")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button {
                            screenshotService.takeScreenshot()
                        } label: {
                            Image(systemName: "camera")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Take screenshot")
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                    if memoryStore.screenshots.isEmpty {
                        Text("No screenshots yet")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                            ForEach(memoryStore.screenshots) { item in
                                ScreenshotThumbnail(item: item, onDelete: {
                                    memoryStore.deleteScreenshot(item)
                                })
                            }
                        }
                        .padding(.horizontal, 8)
                    }

                    // Voice notes
                    HStack {
                        Text("Voice")
                            .font(.system(size: 8, weight: .medium))
                            .textCase(.uppercase)
                            .foregroundStyle(.tertiary)
                        if !memoryStore.voiceNotes.isEmpty {
                            Text("(\(memoryStore.voiceNotes.count))")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                    if memoryStore.voiceNotes.isEmpty && !voiceRecorder.isRecording {
                        Text("No voice notes yet")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.secondary.opacity(0.2))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 2) {
                            ForEach(memoryStore.voiceNotes) { item in
                                VoiceNoteRow(item: item, onDelete: {
                                    memoryStore.deleteVoiceNote(item)
                                })
                            }
                        }
                        .padding(.horizontal, 8)
                    }

                    // Record button
                    Button {
                        if voiceRecorder.isRecording {
                            voiceRecorder.stopRecording()
                            // Give file system a moment, then reload
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                memoryStore.reload()
                            }
                        } else {
                            memoryStore.ensureTodayFolder()
                            voiceRecorder.startRecording(to: memoryStore.todayFolderURL)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if voiceRecorder.isRecording {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 6, height: 6)
                                Text(voiceRecorder.formattedElapsedTime)
                                    .font(.system(size: 10, design: .monospaced))
                                Text("Stop")
                                    .font(.system(size: 10))
                            } else {
                                Image(systemName: "mic")
                                    .font(.system(size: 10))
                                Text("Record")
                                    .font(.system(size: 10))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(voiceRecorder.isRecording ? Color.red.opacity(0.1) : Color.primary.opacity(0.04))
                        .foregroundStyle(voiceRecorder.isRecording ? Color.red : Color.secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 8)
                    .padding(.top, 6)
                }
            }

            Divider()

            // Date navigation
            HStack {
                Button {
                    memoryStore.goToPreviousDay()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    memoryStore.goToToday()
                } label: {
                    Text(memoryStore.displayDate)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    memoryStore.goToNextDay()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(memoryStore.canGoForward ? .secondary : Color.secondary.opacity(0.2))
                }
                .buttonStyle(.plain)
                .disabled(!memoryStore.canGoForward)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Sub-views

struct ScreenshotThumbnail: View {
    let item: ScreenshotItem
    var onDelete: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            if let nsImage = NSImage(contentsOf: item.url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 50)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
            }
            Text(item.timeString)
                .font(.system(size: 7))
                .foregroundStyle(.tertiary)
        }
        .onTapGesture(count: 2) {
            NSWorkspace.shared.open(item.url)
        }
        .contextMenu {
            Button {
                NSWorkspace.shared.open(item.url)
            } label: {
                Label("Open", systemImage: "eye")
            }
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Label("Show in Finder", systemImage: "folder")
            }
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct VoiceNoteRow: View {
    let item: VoiceNoteItem
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mic.fill")
                .font(.system(size: 9))
                .foregroundStyle(Color.red.opacity(0.6))
            Text(item.filename)
                .font(.system(size: 9))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text(item.timeString)
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onTapGesture {
            NSWorkspace.shared.open(item.url)
        }
        .contextMenu {
            Button {
                NSWorkspace.shared.open(item.url)
            } label: {
                Label("Play", systemImage: "play")
            }
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
