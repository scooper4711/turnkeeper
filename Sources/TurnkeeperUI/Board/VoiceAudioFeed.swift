import AVFoundation
import Foundation
import Speech
import TurnkeeperKit

/// What the microphone tap does on the audio thread: hands each buffer to the current recognition request, and
/// about 20 times a second works out the listening meter's levels.
///
/// The request changes after each utterance while the tap keeps running, so it sits behind a lock.
final class VoiceAudioFeed: @unchecked Sendable {
    static let bandCount = 24
    /// Seconds between two sets of levels: about 20 a second, so SwiftUI isn't flooded.
    private static let levelInterval = 0.05

    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var lastLevels: TimeInterval = 0

    /// Sends buffers to `request` from now on; nil drops them.
    func feed(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.withLock { self.request = request }
    }

    /// Passes a buffer on to the recognizer, and returns the meter's levels when it's time for new ones.
    func receive(_ buffer: AVAudioPCMBuffer) -> [Float]? {
        let now = ProcessInfo.processInfo.systemUptime
        let isDue = lock.withLock {
            request?.append(buffer)
            guard now - lastLevels >= Self.levelInterval else { return false }
            lastLevels = now
            return true
        }
        guard isDue, let channel = buffer.floatChannelData?[0] else { return nil }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        let analyzer = SpectrumAnalyzer(sampleRate: buffer.format.sampleRate)
        return analyzer.bands(of: samples, count: Self.bandCount)
    }

    /// Made-up levels for scripted speech, so screenshots show the meter moving: a voice-like hump.
    static func fakeLevels() -> [Float] {
        (0..<bandCount).map { band in
            let hump = sin(Float(band) / Float(bandCount) * .pi)
            return min(max(hump * Float.random(in: 0.5...0.95), 0), 1)
        }
    }
}
