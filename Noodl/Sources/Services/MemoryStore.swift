import Foundation
import Observation
import AppKit

@MainActor
@Observable
final class MemoryStore {
    var currentDate: Date = .now
    var screenshots: [ScreenshotItem] = []
    var voiceNotes: [VoiceNoteItem] = []
    var isSummarizing = false
    var summaryResult: String?

    private let baseURL: URL
    private var watcher: FileWatcher?

    var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "dd-MM-yyyy"
        return f.string(from: currentDate)
    }

    var displayDate: String {
        if Calendar.current.isDateInToday(currentDate) { return "Today" }
        if Calendar.current.isDateInYesterday(currentDate) { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "dd.MM.yyyy"
        return f.string(from: currentDate)
    }

    var todayFolderURL: URL {
        baseURL.appendingPathComponent("memory").appendingPathComponent(dateString)
    }

    var canGoForward: Bool {
        !Calendar.current.isDateInToday(currentDate)
    }

    private var started = false

    init(baseURL: URL) {
        self.baseURL = baseURL
    }

    /// Call from onAppear to defer heavy work out of @State init
    func startIfNeeded() {
        guard !started else { return }
        started = true
        ensureTodayFolder()
        reload()
        startWatching()
    }

    func goToPreviousDay() {
        currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        stopWatching()
        reload()
        startWatching()
    }

    func goToNextDay() {
        guard canGoForward else { return }
        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        stopWatching()
        reload()
        startWatching()
    }

    func goToToday() {
        currentDate = .now
        stopWatching()
        reload()
        startWatching()
    }

    func reload() {
        let folder = todayFolderURL
        let fm = FileManager.default

        guard fm.fileExists(atPath: folder.path) else {
            screenshots = []
            voiceNotes = []
            return
        }

        let files = (try? fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []

        screenshots = files
            .filter { $0.pathExtension.lowercased() == "png" || $0.pathExtension.lowercased() == "jpg" }
            .compactMap { url -> ScreenshotItem? in
                let attrs = try? fm.attributesOfItem(atPath: url.path)
                let date = attrs?[.modificationDate] as? Date ?? .now
                return ScreenshotItem(url: url, capturedAt: date)
            }
            .sorted { $0.capturedAt > $1.capturedAt }

        voiceNotes = files
            .filter { $0.pathExtension.lowercased() == "m4a" }
            .compactMap { url -> VoiceNoteItem? in
                let attrs = try? fm.attributesOfItem(atPath: url.path)
                let date = attrs?[.modificationDate] as? Date ?? .now
                return VoiceNoteItem(url: url, recordedAt: date)
            }
            .sorted { $0.recordedAt > $1.recordedAt }
    }

    func deleteScreenshot(_ item: ScreenshotItem) {
        try? FileManager.default.removeItem(at: item.url)
        screenshots.removeAll { $0.id == item.id }
    }

    func deleteVoiceNote(_ item: VoiceNoteItem) {
        try? FileManager.default.removeItem(at: item.url)
        voiceNotes.removeAll { $0.id == item.id }
    }

    func summarize() {
        isSummarizing = true
        summaryResult = nil
        let folder = todayFolderURL.path
        Task.detached {
            let result = await CommandRunner.run(shell: "claude -p 'Summarize the contents of the daily memory folder at \(folder). Describe any screenshots (list filenames) and voice recordings. Give a brief structured summary of the day.' --no-input 2>&1")
            await MainActor.run {
                self.isSummarizing = false
                self.summaryResult = result.output
            }
        }
    }

    func ensureTodayFolder() {
        let folder = todayFolderURL
        if !FileManager.default.fileExists(atPath: folder.path) {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }
    }

    private func startWatching() {
        let folder = todayFolderURL
        ensureTodayFolder()
        let watcher = FileWatcher(url: folder)
        watcher.onChange = { [weak self] in
            DispatchQueue.main.async {
                self?.reload()
            }
        }
        watcher.start()
        self.watcher = watcher
    }

    private func stopWatching() {
        watcher?.stop()
        watcher = nil
    }
}

struct ScreenshotItem: Identifiable {
    let id = UUID()
    let url: URL
    let capturedAt: Date

    var filename: String { url.lastPathComponent }

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: capturedAt)
    }
}

struct VoiceNoteItem: Identifiable {
    let id = UUID()
    let url: URL
    let recordedAt: Date

    var filename: String { url.lastPathComponent }

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: recordedAt)
    }
}
