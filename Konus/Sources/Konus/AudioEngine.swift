import AVFoundation
import Foundation

protocol AudioEngineDelegate: AnyObject {
    func audioEngine(_ engine: AudioEngine, didDetectLevel rms: Float)
    func audioEngineDidStartSpeech(_ engine: AudioEngine)
    func audioEngine(_ engine: AudioEngine, didEndSpeechWith wavData: Data)
    func audioEngine(_ engine: AudioEngine, didEncounterError message: String)
}

final class AudioEngine {
    weak var delegate: AudioEngineDelegate?

    private var engine = AVAudioEngine()
    private var isRunning = false
    private var tapInstalled = false

    // Audio format
    private let sampleRate: Double = 16000
    private let channels: UInt32 = 1
    private let bytesPerSample = 2 // 16-bit

    // VAD
    private let rmsThreshold: Float = 200
    private let minSpeechFrames = 3
    private let maxDurationSeconds: Double = 30
    private let frameDuration: Double = 0.03 // 30ms

    private var silenceTimeoutSeconds: Double = 1.5
    private var silenceTimeoutFrames: Int { Int(ceil(silenceTimeoutSeconds / frameDuration)) }
    private var maxFrames: Int { Int(ceil(maxDurationSeconds / frameDuration)) }

    // State
    private var inSpeech = false
    private var speechFrameCount = 0
    private var silenceFrameCount = 0
    private var totalFrames = 0
    private var pcmBuffers: [Data] = []

    // Frame size: 30ms at 16kHz = 480 samples = 960 bytes
    private var frameBytes: Int { Int(sampleRate * frameDuration) * bytesPerSample }
    private var pendingData = Data()

    init() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleConfigChange),
            name: .AVAudioEngineConfigurationChange, object: nil
        )
    }

    @objc private func handleConfigChange(_ notification: Notification) {
        NSLog("[konus] Audio configuration changed (device switch)")
        let wasRunning = isRunning
        if isRunning {
            engine.stop()
            isRunning = false
        }
        // Tear down old tap and engine, create fresh one
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        engine = AVAudioEngine()
        resetState()
        if wasRunning {
            start()
        }
    }

    func setSilenceTimeout(_ seconds: Double) {
        silenceTimeoutSeconds = seconds
    }

    func start() {
        guard !isRunning else { return }

        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)

        guard hwFormat.sampleRate > 0, hwFormat.channelCount > 0 else {
            delegate?.audioEngine(self, didEncounterError: "No audio input available")
            return
        }

        // Install tap only once — never remove it, just start/stop the engine
        if !tapInstalled {
            guard let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatInt16,
                sampleRate: sampleRate,
                channels: AVAudioChannelCount(channels),
                interleaved: true
            ) else {
                delegate?.audioEngine(self, didEncounterError: "Cannot create target audio format")
                return
            }

            guard let converter = AVAudioConverter(from: hwFormat, to: targetFormat) else {
                delegate?.audioEngine(self, didEncounterError: "Cannot create audio converter")
                return
            }

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { [weak self] buffer, _ in
                guard let self, self.isRunning else { return }

                // Convert to 16kHz mono Int16
                let outputBuffer = AVAudioPCMBuffer(
                    pcmFormat: targetFormat,
                    frameCapacity: AVAudioFrameCount(Double(buffer.frameLength) * self.sampleRate / hwFormat.sampleRate) + 100
                )!

                var error: NSError?
                let status = converter.convert(to: outputBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                guard status != .error, error == nil else { return }

                let byteCount = Int(outputBuffer.frameLength) * self.bytesPerSample
                guard byteCount > 0, let int16Data = outputBuffer.int16ChannelData else { return }

                let data = Data(bytes: int16Data[0], count: byteCount)
                self.pendingData.append(data)

                // Process complete frames
                while self.pendingData.count >= self.frameBytes {
                    let frame = self.pendingData.prefix(self.frameBytes)
                    self.pendingData = Data(self.pendingData.dropFirst(self.frameBytes))
                    self.processFrame(frame)
                }
            }
            tapInstalled = true
        }

        do {
            engine.prepare()
            try engine.start()
            isRunning = true
            resetState()
        } catch {
            delegate?.audioEngine(self, didEncounterError: "Engine start failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        engine.stop()
        isRunning = false

        // Emit any remaining speech
        if inSpeech && !pcmBuffers.isEmpty {
            emitSpeech()
        }
        resetState()
    }

    private func resetState() {
        inSpeech = false
        speechFrameCount = 0
        silenceFrameCount = 0
        totalFrames = 0
        pcmBuffers = []
        pendingData = Data()
    }

    private func processFrame(_ frame: Data) {
        let rms = calculateRMS(frame)
        let normalizedLevel = min(rms / 2000.0, 1.0)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.audioEngine(self, didDetectLevel: normalizedLevel)
        }

        let isSpeech = rms > rmsThreshold

        if !inSpeech {
            if isSpeech {
                speechFrameCount += 1
                if speechFrameCount >= minSpeechFrames {
                    inSpeech = true
                    silenceFrameCount = 0
                    totalFrames = 0
                    pcmBuffers = []
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.delegate?.audioEngineDidStartSpeech(self)
                    }
                }
            } else {
                speechFrameCount = 0
            }
        }

        if inSpeech {
            pcmBuffers.append(frame)
            totalFrames += 1

            if !isSpeech {
                silenceFrameCount += 1
                if silenceFrameCount >= silenceTimeoutFrames {
                    emitSpeech()
                }
            } else {
                silenceFrameCount = 0
            }

            if totalFrames >= maxFrames {
                emitSpeech()
            }
        }
    }

    private func emitSpeech() {
        let pcm = pcmBuffers.reduce(Data()) { $0 + $1 }
        let wav = pcmToWav(pcm)
        inSpeech = false
        speechFrameCount = 0
        silenceFrameCount = 0
        totalFrames = 0
        pcmBuffers = []

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.delegate?.audioEngine(self, didEndSpeechWith: wav)
        }
    }

    private func calculateRMS(_ data: Data) -> Float {
        data.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Int16.self)
            var sum: Float = 0
            for sample in samples {
                let f = Float(sample)
                sum += f * f
            }
            return sqrt(sum / Float(max(samples.count, 1)))
        }
    }

    private func pcmToWav(_ pcm: Data) -> Data {
        var wav = Data()
        let dataSize = UInt32(pcm.count)
        let fileSize = dataSize + 36

        // RIFF header
        wav.append(contentsOf: "RIFF".utf8)
        wav.append(littleEndian: fileSize)
        wav.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        wav.append(contentsOf: "fmt ".utf8)
        wav.append(littleEndian: UInt32(16))      // chunk size
        wav.append(littleEndian: UInt16(1))       // PCM format
        wav.append(littleEndian: UInt16(channels)) // channels
        wav.append(littleEndian: UInt32(sampleRate)) // sample rate
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bytesPerSample)
        wav.append(littleEndian: byteRate)
        let blockAlign = UInt16(channels) * UInt16(bytesPerSample)
        wav.append(littleEndian: blockAlign)
        wav.append(littleEndian: UInt16(bytesPerSample * 8)) // bits per sample

        // data chunk
        wav.append(contentsOf: "data".utf8)
        wav.append(littleEndian: dataSize)
        wav.append(pcm)

        return wav
    }
}

// MARK: - Data helpers

private extension Data {
    mutating func append(littleEndian value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }
    mutating func append(littleEndian value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }
}
