//
//  BackgroundKeepAlive.swift
//  Aidoku
//

import AVFoundation
import UIKit

final class BackgroundKeepAlive: @unchecked Sendable {
    enum Reason: Hashable {
        case download
        case libraryRefresh
    }

    static let shared = BackgroundKeepAlive()

    private let queue = DispatchQueue(label: "app.aidoku.Aidoku.BackgroundKeepAlive")
    private var reasons: Set<Reason> = []
    private var isBackground = false
    private var sessionActive = false
    private var player: AVAudioPlayer?

    private init() {
        let center = NotificationCenter.default
        center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.queue.async {
                self?.isBackground = true
                self?.evaluate()
            }
        }
        center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.queue.async {
                self?.isBackground = false
                self?.evaluate()
            }
        }
        center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard
                let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                AVAudioSession.InterruptionType(rawValue: rawType) == .ended
            else { return }
            self?.queue.async { self?.evaluate() }
        }

        DispatchQueue.main.async { [weak self] in
            let background = UIApplication.shared.applicationState == .background
            self?.queue.async {
                self?.isBackground = background
                self?.evaluate()
            }
        }
    }

    func set(_ reason: Reason, active: Bool) {
        queue.async { [self] in
            if active {
                reasons.insert(reason)
            } else {
                reasons.remove(reason)
            }
            evaluate()
        }
    }

    private func evaluate() {
        if isBackground && !reasons.isEmpty {
            startPlayback()
        } else {
            stopPlayback()
        }
    }

    private func startPlayback() {
        if player?.isPlaying == true { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            sessionActive = true

            let player = try self.player ?? AVAudioPlayer(data: Self.silentWAV())
            player.numberOfLoops = -1
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            LogManager.logger.error("Failed to start background keep-alive audio: \(error)")
        }
    }

    private func stopPlayback() {
        player?.stop()
        player = nil
        if sessionActive {
            sessionActive = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private static func silentWAV() -> Data {
        let sampleRate: UInt32 = 8000
        let dataSize = sampleRate * 2
        var data = Data()

        func append(_ string: String) {
            data.append(contentsOf: Array(string.utf8))
        }
        func append32(_ value: UInt32) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        func append16(_ value: UInt16) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        append("RIFF")
        append32(36 + dataSize)
        append("WAVE")
        append("fmt ")
        append32(16)
        append16(1)
        append16(1)
        append32(sampleRate)
        append32(sampleRate * 2)
        append16(2)
        append16(16)
        append("data")
        append32(dataSize)
        data.append(Data(count: Int(dataSize)))
        return data
    }
}
