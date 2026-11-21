import AVFoundation
import UIKit

/// Bell chimes, synthesized so the app ships no audio files. Mirrors `sound` in docs/scene.js.
@MainActor
final class Bells {
    static let shared = Bells()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var ready = false
    private let scale: [Double] = [523.25, 587.33, 659.25, 783.99, 880, 1046.5, 1174.66, 1318.5, 1567.98, 1760]

    private var enabled: Bool {
        UserDefaults.standard.object(forKey: "sound.on") as? Bool ?? true
    }

    /// Each day rings a little higher up a pentatonic scale; the 24th gets the full run.
    func chime(day: Int) {
        if day == 24 { return play([0, 2, 4, 5, 7, 9, 7, 9].map { scale[$0] }, gap: 0.16, volume: 0.2) }
        let i = (day - 1) % 6
        play([scale[i], scale[i + 2], scale[i + 4]], gap: 0.13, volume: 0.2)
    }

    func star(_ n: Int) {
        let notes = [659.25, 783.99, 880, 1046.5, 1318.5]
        play([notes[min(max(n, 1), 5) - 1]], gap: 0, volume: 0.14)
    }

    private func start() -> Bool {
        if ready { return engine.isRunning || ((try? engine.start()) != nil) }
        do {
            // Ambient: follows the silent switch and plays over the user's own music.
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            try engine.start()
            ready = true
            return true
        } catch {
            return false
        }
    }

    private func play(_ notes: [Double], gap: Double, volume: Float) {
        guard enabled, start() else { return }
        let rate = format.sampleRate
        let frames = AVAudioFrameCount((Double(notes.count - 1) * gap + 2.9) * rate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames), let out = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames
        for i in 0..<Int(frames) { out[i] = 0 }
        // Partials of a small bell: multiple of the note, loudness, seconds to fade.
        let partials: [(Double, Double, Double)] = [(1, 1, 2.4), (2.76, 0.32, 1.3), (5.4, 0.14, 0.7), (0.5, 0.25, 2.8)]
        for (n, note) in notes.enumerated() {
            let offset = Int(Double(n) * gap * rate)
            for (multiple, loudness, fade) in partials {
                let step = 2 * Double.pi * note * multiple / rate
                let decay = log(10_000) / (fade * rate)
                let count = min(Int(fade * rate), Int(frames) - offset)
                for i in 0..<max(count, 0) {
                    let attack = min(1, Double(i) / (0.006 * rate))
                    out[offset + i] += Float(sin(step * Double(i)) * loudness * attack * exp(-decay * Double(i))) * volume
                }
            }
        }
        player.scheduleBuffer(buffer, at: nil, options: [])
        if !player.isPlaying { player.play() }
    }
}

@MainActor
enum Haptics {
    static func tick() { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.6) }
    static func open() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func done() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func locked() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
