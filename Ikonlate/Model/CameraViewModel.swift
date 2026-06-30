//
//  CameraViewModel.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import Foundation
import Observation
import Translation
import UIKit
import Vision

@MainActor
@Observable
final class CameraViewModel {

    var image: UIImage?
    var recognizedText = ""
    var translatedText = ""
    var configuration: TranslationSession.Configuration?
    var isRecognizing = false
    var isTranslating = false
    var errorMessage: String?

    var hasRecognizedText: Bool {
        !recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func processImage(
        _ image: UIImage,
        noTextMessage: String,
        errorMessage: String
    ) async {
        self.image = image
        recognizedText = ""
        translatedText = ""
        self.errorMessage = nil
        isRecognizing = true

        do {
            let text = try await recognizeText(in: image)
            recognizedText = text
            self.errorMessage = text.isEmpty ? noTextMessage : nil
        } catch {
            self.errorMessage = errorMessage
        }

        isRecognizing = false
    }

    func triggerTranslation() {
        guard hasRecognizedText else { return }

        translatedText = ""
        errorMessage = nil
        isTranslating = true

        let newConfiguration = TranslationSession.Configuration(
            source: nil,
            target: nil,
            preferredStrategy: .lowLatency
        )
        if configuration == nil {
            configuration = newConfiguration
        } else {
            configuration = newConfiguration
            configuration?.invalidate()
        }
    }

    func translate(using session: TranslationSession, errorMessage: String)
        async
    {
        do {
            let response = try await session.translate(recognizedText)
            translatedText = response.targetText
            isTranslating = false
            self.errorMessage = nil
        } catch {
            isTranslating = false
            self.errorMessage = errorMessage
        }
    }

    private nonisolated func recognizeText(in image: UIImage) async throws
        -> String
    {
        guard let cgImage = image.cgImage else { return "" }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations =
                        request.results as? [VNRecognizedTextObservation] ?? []
                    let lines = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    continuation.resume(
                        returning: lines.joined(separator: "\n")
                    )
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true

                let handler = VNImageRequestHandler(
                    cgImage: cgImage,
                    orientation: image.cgImagePropertyOrientation
                )

                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension UIImage {
    fileprivate var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:
            .up
        case .upMirrored:
            .upMirrored
        case .down:
            .down
        case .downMirrored:
            .downMirrored
        case .left:
            .left
        case .leftMirrored:
            .leftMirrored
        case .right:
            .right
        case .rightMirrored:
            .rightMirrored
        @unknown default:
            .up
        }
    }
}
