//
//  SpeechRecognitionController.swift
//  Ikonlate
//
//  Created by Codex on 01.07.26.
//

import AVFAudio
import Foundation
import Speech

final class SpeechRecognitionController {

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?

    var isRunning: Bool {

        audioEngine.isRunning
    }

    func start(

        languageIdentifier: String,
        onTextChange: @escaping @MainActor (String) -> Void,
        onError: @escaping @MainActor (String) -> Void
    ) async {
        stop()

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
            try configureAudioSession()
            try startAudioEngine(
                recognizer: recognizer,
                onTextChange: onTextChange,
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

        if audioEngine.isRunning {
            audioEngine.stop()
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
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

    private func configureAudioSession() throws {

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .record,
            mode: .measurement,
            options: [.duckOthers]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startAudioEngine(

        recognizer: SFSpeechRecognizer,
        onTextChange: @escaping @MainActor (String) -> Void,
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

        inputNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: recordingFormat
        ) {
            [weak self]
            buffer,
            _ in
            self?.recognitionRequest?.append(buffer)
        }

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
