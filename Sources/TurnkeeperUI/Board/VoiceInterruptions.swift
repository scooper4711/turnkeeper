import AVFoundation
import Foundation

/// Watches for what stops the microphone while the voice initiative screen is open: a phone call or Siri (an audio
/// session interruption, on iOS) and a change of input device (the engine's configuration changes and it stops).
///
/// The notifications arrive on the main queue, but their blocks are built in `nonisolated` helpers that hop to the
/// main actor, as `VoiceInitiative` does for its framework callbacks.
@MainActor
final class VoiceInterruptions {
    private var observers: [NSObjectProtocol] = []

    /// Calls `pause` when an interruption begins, and `resume` when it ends or the engine needs starting again.
    func watch(
        _ engine: AVAudioEngine,
        pause: @escaping @MainActor @Sendable () -> Void,
        resume: @escaping @MainActor @Sendable () -> Void
    ) {
        stop()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine,
                                            queue: .main, using: Self.configurationBlock(resume: resume)))
        #if os(iOS)
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil,
                                            queue: .main, using: Self.interruptionBlock(pause: pause, resume: resume)))
        #endif
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }

    private nonisolated static func configurationBlock(
        resume: @escaping @MainActor @Sendable () -> Void
    ) -> @Sendable (Notification) -> Void {
        { _ in Task { @MainActor in resume() } }
    }

    #if os(iOS)
    private nonisolated static func interruptionBlock(
        pause: @escaping @MainActor @Sendable () -> Void,
        resume: @escaping @MainActor @Sendable () -> Void
    ) -> @Sendable (Notification) -> Void {
        { notification in
            let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let hasBegun = raw.flatMap(AVAudioSession.InterruptionType.init) == .began
            Task { @MainActor in hasBegun ? pause() : resume() }
        }
    }
    #endif
}
