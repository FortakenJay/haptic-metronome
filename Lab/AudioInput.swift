import AVFAudio
import Foundation

/// Seconds on the host clock (mach_absolute_time), the clock audio buffers are stamped with.
func hostNow() -> Double {
    AVAudioTime.seconds(forHostTime: mach_absolute_time())
}

/// The watch microphone, feeding an `OnsetDetector` on the audio thread.
///
/// Onsets come back as host-clock seconds through `onOnsets`, on the audio thread; the caller hops to the main
/// actor. Measurement mode turns off the system's voice processing (gain control, noise suppression), which
/// would smear note attacks.
final class AudioInput {
    enum Failure: LocalizedError {
        case noMicrophone
        var errorDescription: String? { "The microphone isn't available." }
    }

    private let engine = AVAudioEngine()
    private(set) var sampleRate: Double = 0
    private var running = false

    func start(onOnsets: @escaping @Sendable ([Double]) -> Void) throws {
        guard !running else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement)
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw Failure.noMicrophone }
        sampleRate = format.sampleRate
        let detector = OnsetDetector(parameters: OnsetParameters(sampleRate: format.sampleRate))
        let rate = format.sampleRate

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, when in
            guard let channel = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channel, count: count))
            let start = when.isHostTimeValid
                ? AVAudioTime.seconds(forHostTime: when.hostTime)
                : hostNow() - Double(count) / rate
            let onsets = detector.process(samples, startTime: start)
            if !onsets.isEmpty { onOnsets(onsets) }
        }
        engine.prepare()
        try engine.start()
        running = true
    }

    func stop() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        running = false
    }
}
