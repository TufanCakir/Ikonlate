//
//  SpeechRecognitionController.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import AVFAudio
import Foundation
import Speech

final class SpeechRecognitionController {

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var hasInstalledAudioTap = false

    var isRunning: Bool {

        audioEngine.isRunning
    }

    func start(

        languageIdentifier: String,
        onTextChange: @escaping @MainActor (String) -> Void,
        onAudioLevelChange: @escaping @MainActor (Float) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) async {
        stop(deactivateAudioSession: false)

        let isAuthorized = await requestSpeechAuthorization()
        guard isAuthorized else {
            await MainActor.run {
                onError("speech.error.permission")
            }
            return
        }

        let hasMicrophoneAccess = await requestMicrophonePermission()
        guard hasMicrophoneAccess else {
            await MainActor.run {
                onError("speech.error.microphone")
            }
            return
        }

        guard
            let recognizer = SFSpeechRecognizer(
                locale: Locale(identifier: languageIdentifier)
            ), recognizer.isAvailable
        else {
            await MainActor.run {
                onError("speech.error.unavailable")
            }
            return
        }

        speechRecognizer = recognizer

        do {
            try await configureAudioSession()
            try startAudioEngine(
                recognizer: recognizer,
                onTextChange: onTextChange,
                onAudioLevelChange: onAudioLevelChange,
                onError: onError
            )
        } catch {
            stop()
            await MainActor.run {
                let messageKey =
                    (error as? SpeechRecognitionControllerError)?.messageKey
                    ?? "speech.error.start"
                onError(messageKey)
            }
        }
    }

    func stop() {
        stop(deactivateAudioSession: true)
    }

    private func stop(deactivateAudioSession: Bool) {

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if hasInstalledAudioTap {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasInstalledAudioTap = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        if deactivateAudioSession {
            AVAudioSession.sharedInstance().deactivate { _, _ in }
        }
    }

    private func requestSpeechAuthorization() async -> Bool {

        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {

        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { isAllowed in
                continuation.resume(returning: isAllowed)
            }
        }
    }

    private func configureAudioSession() async throws {
        let audioSession = AVAudioSession.sharedInstance()

        try audioSession.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [
                .allowBluetoothHFP,
                .defaultToSpeaker,
                .duckOthers,
            ]
        )

        try await audioSession.activate()
    }

    private func startAudioEngine(

        recognizer: SFSpeechRecognizer,
        onTextChange: @escaping @MainActor (String) -> Void,
        onAudioLevelChange: @escaping @MainActor (Float) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0,
            recordingFormat.channelCount > 0
        else {
            throw SpeechRecognitionControllerError.invalidInputFormat
        }

        try inputNode.installAudioTap(
            onBus: 0,
            bufferSize: 1024,
            format: recordingFormat,
            tapProvider: { readOnlyBuffer, _ in
                request.append(AVAudioPCMBuffer(copying: readOnlyBuffer))

                let level = Self.normalizedAudioLevel(from: readOnlyBuffer)
                Task { @MainActor in
                    onAudioLevelChange(level)
                }
            }
        )
        hasInstalledAudioTap = true

        recognitionTask = recognizer.recognitionTask(with: request) {
            [weak self]
            result,
            error in
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    onTextChange(text)
                }
            }

            if error != nil {
                self?.stop()
                Task { @MainActor in
                    onError("speech.error.recognition")
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    nonisolated private static func normalizedAudioLevel(
        from buffer: AVReadOnlyAudioPCMBuffer
    ) -> Float {
        guard buffer.format.channelCount > 0 else { return 0 }

        let meanAmplitude: Float
        switch buffer.channelData(0) {
        case .float(let samples):
            guard !samples.isEmpty else { return 0 }
            var total: Float = 0
            for sample in samples {
                total += abs(sample)
            }
            meanAmplitude = total / Float(samples.count)
        case .int16(let samples):
            guard !samples.isEmpty else { return 0 }
            var total: Float = 0
            for sample in samples {
                total += abs(Float(sample) / Float(Int16.max))
            }
            meanAmplitude = total / Float(samples.count)
        case .int32(let samples):
            guard !samples.isEmpty else { return 0 }
            var total: Float = 0
            for sample in samples {
                total += abs(Float(sample) / Float(Int32.max))
            }
            meanAmplitude = total / Float(samples.count)
        @unknown default:
            return 0
        }

        return min(max(meanAmplitude * 12, 0.06), 1)
    }
}

private enum SpeechRecognitionControllerError: Error {

    case invalidInputFormat

    var messageKey: String {
        switch self {
        case .invalidInputFormat:
            "speech.error.inputFormat"
        }
    }
}
