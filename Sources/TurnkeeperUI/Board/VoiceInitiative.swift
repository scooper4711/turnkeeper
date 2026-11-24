import AVFoundation
import Observation
import Speech

/// Speech recognition for the voice initiative screen: it listens the whole time the screen is open and splits
/// what it hears into utterances, on the device where it can be.
///
/// An utterance ends when the transcript stays the same for 0.7 s, or when the recognizer calls it final; that
/// keeps "twenty" from being taken before "twenty-three". After each utterance, after an error, and before
/// Apple's one-minute limit on a task, a new recognition task starts while the microphone keeps running.
///
/// The Speech and audio frameworks call back on their own queues. Those callbacks are built in `nonisolated`
/// helpers below: a closure written inside this main-actor class would be main-actor isolated, and Swift 6
/// traps when the framework calls it from another queue.
@Observable
@MainActor
final class VoiceInitiative {
    static let shared = VoiceInitiative()
    /// How long the transcript must stay the same to end an utterance.
    private static let pause = Duration.milliseconds(700)
    /// A new task starts before Apple's one-minute limit on one.
    private static let taskLimit = Duration.seconds(50)

    private(set) var isListening = false
    /// What has been heard of the current utterance.
    private(set) var transcript = ""
    private(set) var isAvailable = false
    /// Why voice entry is off, for the screen to explain; empty when it's available.
    private(set) var unavailableReason = ""
    /// The listening meter's bars, 0 to 1, low frequencies first. All zeros when not listening.
    private(set) var levels = VoiceInitiative.silence

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let feed = VoiceAudioFeed()
    @ObservationIgnored private let interruptions = VoiceInterruptions()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    /// Counts recognition tasks, so results from one already replaced are ignored.
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var pauseTimer: Task<Void, Never>?
    @ObservationIgnored private var limitTimer: Task<Void, Never>?
    @ObservationIgnored private var contextualStrings: [String] = []
    @ObservationIgnored private var onPartial: (String) -> Void = { _ in }
    @ObservationIgnored private var onUtterance: (String) -> Void = { _ in }
    /// For UI tests: the utterances the "microphone" hears, from `--fake-voice 17,Merisiel,nat 20`.
    @ObservationIgnored private var scripted: [String]?
    @ObservationIgnored private var script: Task<Void, Never>?

    private static let silence = [Float](repeating: 0, count: VoiceAudioFeed.bandCount)

    private init() {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--fake-voice"), arguments.indices.contains(index + 1) {
            scripted = arguments[index + 1].split(separator: ",").map(String.init)
        }
    }

    /// Asks for speech and microphone permission; voice entry stays off if either is refused.
    func requestPermission() async {
        guard scripted == nil else {
            isAvailable = true
            return
        }
        let speech = await Self.speechAuthorization()
        let microphone = await AVAudioApplication.requestRecordPermission()
        isAvailable = speech == .authorized && microphone && recognizer?.isAvailable == true
        unavailableReason = switch (speech == .authorized, microphone, recognizer?.isAvailable == true) {
        case (false, _, _): "Voice entry needs Speech Recognition access in Settings."
        case (_, false, _): "Voice entry needs Microphone access in Settings."
        case (_, _, false): "Speech recognition isn't available right now."
        default: ""
        }
    }

    /// Starts listening until `stop()`. `onPartial` gets the transcript as it grows; `onUtterance` gets each
    /// finished utterance. Numbers, "nat 20" and `names` are primed as likely words, which makes them much more
    /// accurate.
    func start(names: [String], onPartial: @escaping (String) -> Void, onUtterance: @escaping (String) -> Void) {
        guard isAvailable, !isListening else { return }
        self.onPartial = onPartial
        self.onUtterance = onUtterance
        contextualStrings = (1...60).map(String.init) + ["nat 20", "natural 20"] + names
        isListening = true
        if scripted != nil {
            playScript()
            return
        }
        resumeAudio()
        interruptions.watch(engine, pause: { [weak self] in self?.pauseAudio() },
                            resume: { [weak self] in self?.resumeAudio() })
    }

    /// Stops listening and forgets the current utterance.
    func stop() {
        isListening = false
        interruptions.stop()
        script?.cancel()
        endRecognition()
        stopAudio()
        transcript = ""
        levels = Self.silence
        onPartial = { _ in }
        onUtterance = { _ in }
    }

    // MARK: Utterances

    private func receive(_ text: String, generation: Int) {
        guard isListening, generation == self.generation, text != transcript else { return }
        transcript = text
        onPartial(text)
        restartPauseTimer()
    }

    /// The recognizer called the utterance final.
    private func receiveFinal(_ text: String, generation: Int) {
        receive(text, generation: generation)
        guard isListening, generation == self.generation else { return }
        endUtterance()
    }

    /// The recognizer gave up, such as after a long silence: what was heard counts, and listening goes on. With
    /// nothing heard it waits a second first, so an error that keeps coming back doesn't spin.
    private func receiveError(generation: Int) {
        guard isListening, generation == self.generation else { return }
        guard transcript.isEmpty else { return endUtterance() }
        endRecognition()
        limitTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, let self, self.isListening else { return }
            self.startRecognition()
        }
    }

    /// Hands on what was heard, if anything, and starts afresh with an empty transcript.
    private func endUtterance() {
        let heard = transcript
        endRecognition()
        transcript = ""
        if isListening, scripted == nil { startRecognition() }
        if !heard.isEmpty { onUtterance(heard) }
    }

    private func restartPauseTimer() {
        pauseTimer?.cancel()
        pauseTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.pause)
            guard !Task.isCancelled else { return }
            self?.endUtterance()
        }
    }

    /// Plays the scripted utterances half a second apart, each heard first as a partial.
    private func playScript() {
        script = Task { [weak self] in
            while let self, self.isListening, let next = self.scripted?.first {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                self.scripted?.removeFirst()
                self.levels = VoiceAudioFeed.fakeLevels()
                self.receive(next, generation: self.generation)
                self.endUtterance()
            }
            self?.levels = Self.silence
        }
    }

    // MARK: Recognition and audio

    private func startRecognition() {
        guard let recognizer else { return }
        generation += 1
        let request = SFSpeechAudioBufferRecognitionRequest()
        // On the device when it can be, so what's said never leaves it; otherwise Apple's server recognizer.
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        request.shouldReportPartialResults = true
        request.contextualStrings = contextualStrings
        self.request = request
        feed.feed(request)
        task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler(for: self, generation))
        limitTimer = Task { [weak self] in
            try? await Task.sleep(for: Self.taskLimit)
            guard !Task.isCancelled else { return }
            self?.endUtterance()
        }
    }

    private func endRecognition() {
        pauseTimer?.cancel()
        limitTimer?.cancel()
        feed.feed(nil)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }

    /// Starts, or after an interruption or a change of microphone restarts, the audio and recognition. When the
    /// microphone can't start, listening stops and the screen says why.
    private func resumeAudio() {
        guard isListening, scripted == nil else { return }
        endRecognition()
        stopAudio()
        do {
            try startAudio()
            startRecognition()
        } catch {
            stop()
            isAvailable = false
            unavailableReason = "The microphone couldn't start. Close this screen and open it again."
        }
    }

    /// A call or Siri took the microphone: listening waits until the interruption ends.
    private func pauseAudio() {
        guard isListening, scripted == nil else { return }
        endRecognition()
        stopAudio()
        transcript = ""
        levels = Self.silence
    }

    private func startAudio() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0 else { throw VoiceError.noMicrophone }
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tapBlock(feed: feed, voice: self))
        engine.prepare()
        try engine.start()
    }

    private func stopAudio() {
        guard scripted == nil else { return }
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func show(_ levels: [Float]) {
        guard isListening else { return }
        self.levels = levels
    }

    // MARK: Callbacks that run on the frameworks' queues

    private nonisolated static func speechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in continuation.resume(returning: status) }
        }
    }

    private nonisolated static func tapBlock(feed: VoiceAudioFeed, voice: VoiceInitiative) -> AVAudioNodeTapBlock {
        { [weak voice] buffer, _ in
            guard let levels = feed.receive(buffer) else { return }
            Task { @MainActor in voice?.show(levels) }
        }
    }

    private nonisolated static func resultHandler(
        for voice: VoiceInitiative, _ generation: Int
    ) -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak voice] result, error in
            guard let result else {
                if error != nil { Task { @MainActor in voice?.receiveError(generation: generation) } }
                return
            }
            let text = result.bestTranscription.formattedString
            if result.isFinal {
                Task { @MainActor in voice?.receiveFinal(text, generation: generation) }
            } else {
                Task { @MainActor in voice?.receive(text, generation: generation) }
            }
        }
    }
}

enum VoiceError: Error {
    case noMicrophone
}
