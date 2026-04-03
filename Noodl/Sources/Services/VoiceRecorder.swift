import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class VoiceRecorder {
    var isRecording = false
    var elapsedTime: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var outputURL: URL?

    func startRecording(to folder: URL) {
        let timestamp = {
            let f = DateFormatter()
            f.dateFormat = "HHmmss"
            return f.string(from: Date.now)
        }()

        let url = folder.appendingPathComponent("voice-\(timestamp).m4a")
        outputURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            isRecording = true
            elapsedTime = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.elapsedTime += 1
                }
            }
        } catch {
            isRecording = false
        }
    }

    func stopRecording() {
        recorder?.stop()
        recorder = nil
        timer?.invalidate()
        timer = nil
        isRecording = false
        elapsedTime = 0
    }

    var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
