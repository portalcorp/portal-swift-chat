#if os(iOS)

import AVFoundation
import Combine
import SwiftUI
import UIKit

final class AudioRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var levels: [CGFloat] = Array(repeating: 0.1, count: 30)
    @Published var duration: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var recordingURL: URL?

    func startRecording() async throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        if session.recordPermission == .undetermined {
            let granted = await requestPermission(session: session)
            guard granted else {
                throw RecorderError.permissionDenied
            }
        } else if session.recordPermission == .denied {
            throw RecorderError.permissionDenied
        }

        recordingURL = FileManager.default.temporaryDirectory
            .appending(path: "fullmoon-recording-\(UUID().uuidString).m4a")

        guard let recordingURL else {
            throw RecorderError.failedToCreateURL
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
        recorder?.delegate = self
        recorder?.isMeteringEnabled = true
        recorder?.record()

        isRecording = true
        isPaused = false
        startMetering()
    }

    func togglePause() {
        guard let recorder else { return }

        if recorder.isRecording {
            recorder.pause()
            isRecording = false
            isPaused = true
        } else {
            recorder.record()
            isRecording = true
            isPaused = false
        }
    }

    func stopRecording() -> URL? {
        guard let recorder else { return nil }

        recorder.stop()
        duration = recorder.currentTime
        isRecording = false
        isPaused = false
        stopMetering()

        return recorder.url
    }

    func cancelRecording() {
        let url = recorder?.url
        recorder?.stop()
        stopMetering()
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
        resetState()
    }

    func resetState() {
        recorder = nil
        isRecording = false
        isPaused = false
        levels = Array(repeating: 0.1, count: levels.count)
        duration = 0
        recordingURL = nil
    }

    private func startMetering() {
        stopMetering()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.updateMeters()
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func updateMeters() {
        guard let recorder else { return }
        recorder.updateMeters()
        duration = recorder.currentTime

        let power = recorder.averagePower(forChannel: 0)
        let level = CGFloat(normalize(power: power))

        levels.append(level)
        if levels.count > 30 {
            levels.removeFirst(levels.count - 30)
        }
    }

    private func normalize(power: Float) -> Double {
        let minDb: Float = -80
        if power < minDb { return 0 }
        let clamped = max(power, minDb)
        return Double((clamped + 80) / 80)
    }

    private func requestPermission(session: AVAudioSession) async -> Bool {
        await withCheckedContinuation { continuation in
            session.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    enum RecorderError: Error {
        case permissionDenied
        case failedToCreateURL
    }
}

final class AudioPlaybackController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?

    func load(url: URL) {
        player = try? AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        currentTime = 0
        isPlaying = false
    }

    func togglePlay() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            stopDisplayLink()
            isPlaying = false
        } else {
            player.play()
            startDisplayLink()
            isPlaying = true
        }
    }

    func stop() {
        player?.stop()
        player?.currentTime = 0
        stopDisplayLink()
        currentTime = 0
        isPlaying = false
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let boundedTime = max(0, min(time, player.duration))
        player.currentTime = boundedTime
        currentTime = boundedTime
        if !player.isPlaying {
            player.prepareToPlay()
        }
    }

    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(updateTime))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateTime() {
        guard let player else { return }
        currentTime = player.currentTime
        if !player.isPlaying {
            stop()
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
    }
}

struct AudioWaveformView: View {
    var levels: [CGFloat]
    var animate: Bool
    var tint: Color = .accentColor

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let barWidth = max(width / CGFloat(max(levels.count, 1)), 2)
            let gradient = LinearGradient(colors: [tint.opacity(0.25), tint.opacity(0.9)], startPoint: .bottom, endPoint: .top)

            HStack(alignment: .center, spacing: barWidth * 0.25) {
                ForEach(Array(levels.enumerated()), id: \.offset) { item in
                    let value = item.element
                    Capsule()
                        .fill(gradient)
                        .frame(width: barWidth, height: max(value, 0.05) * height)
                        .animation(animate ? .easeOut(duration: 0.1) : .default, value: value)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .clipped()
        }
    }
}

#endif
