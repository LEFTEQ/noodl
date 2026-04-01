import Foundation

final class FileWatcher: @unchecked Sendable {
    private let url: URL
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var debounceWork: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.lefteq.noodl.filewatcher", qos: .utility)
    private let debounceInterval: TimeInterval = 0.1

    var onChange: (() -> Void)?

    init(url: URL) {
        self.url = url
    }

    deinit {
        stop()
    }

    func start() {
        stop()

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        fileDescriptor = open(url.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .attrib],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.handleChange()
        }

        source.setCancelHandler { [weak self] in
            guard let self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        self.source = source
        source.resume()
    }

    func stop() {
        debounceWork?.cancel()
        debounceWork = nil
        source?.cancel()
        source = nil
        // fileDescriptor is closed in cancel handler
    }

    private func handleChange() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        debounceWork = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}
