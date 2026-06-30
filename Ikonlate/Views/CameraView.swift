//
//  CameraView.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import SwiftUI
import Translation
import UIKit

struct CameraView: View {

    @Binding private var searchText: String
    @Binding private var selectedTab: AppTab

    @Environment(AppSettingsViewModel.self) private var settings

    @State private var viewModel = CameraViewModel()
    @State private var isShowingCamera = false

    init(searchText: Binding<String>, selectedTab: Binding<AppTab>) {
        _searchText = searchText
        _selectedTab = selectedTab
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassmorphismBackground(
                    highContrast: settings.highContrast,
                    reduceAnimations: settings.reduceAnimations
                )

                VStack(spacing: 12) {
                    preview
                    actionRow
                    recognizedSection
                    resultSection
                }
                .padding(16)
            }
            .navigationTitle(settings.text("camera.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraPicker { image in
                Task {
                    await viewModel.processImage(
                        image,
                        noTextMessage: settings.text("camera.noText"),
                        errorMessage: settings.text("camera.ocrError")
                    )
                }
            }
        }
        .translationTask(viewModel.configuration) { session in
            await viewModel.translate(
                using: session,
                errorMessage: settings.text("camera.translationError")
            )
        }
    }

    private var preview: some View {
        ZStack {
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(settings.colorTint)
                    Text(settings.text("camera.placeholder"))
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: settings.largeControls ? 210 : 180)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    settings.highContrast
                        ? Color.primary.opacity(0.35)
                        : Color.white.opacity(0.4),
                    lineWidth: 1
                )
        }
        .panelStyle(highContrast: settings.highContrast)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                isShowingCamera = true
            } label: {
                Label(
                    viewModel.image == nil
                        ? settings.text("camera.capture")
                        : settings.text("camera.retake"),
                    systemImage: "camera.fill"
                )
                .frame(maxWidth: .infinity)
                .foregroundStyle(settings.highContrast ? .black : .white)
            }
            .buttonStyle(.borderedProminent)
            .tint(settings.colorTint)

            Button {
                viewModel.triggerTranslation()
            } label: {
                Label(
                    settings.text("camera.translate"),
                    systemImage: "translate"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.hasRecognizedText || viewModel.isTranslating)
        }
        .controlSize(settings.largeControls ? .large : .regular)
    }

    private var recognizedSection: some View {
        compactTextPanel(
            title: settings.text("camera.recognizedTitle"),
            symbolName: viewModel.isRecognizing
                ? "text.viewfinder" : "doc.text.viewfinder",
            text: viewModel.isRecognizing
                ? settings.text("camera.scanning") : viewModel.recognizedText,
            placeholder: settings.text("camera.placeholder")
        )
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            compactTextPanel(
                title: settings.text("camera.resultTitle"),
                symbolName: viewModel.isTranslating
                    ? "sparkles" : "checkmark.bubble",
                text: viewModel.isTranslating
                    ? settings.text("camera.translating")
                    : viewModel.translatedText,
                placeholder: viewModel.errorMessage
                    ?? settings.text("translator.emptyResult")
            )

            if !viewModel.translatedText.isEmpty || viewModel.hasRecognizedText
            {
                Button {
                    searchText =
                        viewModel.translatedText.isEmpty
                        ? viewModel.recognizedText : viewModel.translatedText
                    selectedTab = .translate
                } label: {
                    Label(
                        settings.text("camera.useInTranslator"),
                        systemImage: "arrow.right.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(settings.largeControls ? .large : .regular)
            }
        }
    }

    private func compactTextPanel(
        title: String,
        symbolName: String,
        text: String,
        placeholder: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbolName)
                .font(.headline)
                .translatorSymbolEffect(
                    isActive: viewModel.isRecognizing
                        || viewModel.isTranslating,
                    reduceAnimations: settings.reduceAnimations
                )

            Text(text.isEmpty ? placeholder : text)
                .font(settings.largeControls ? .body : .callout)
                .foregroundStyle(text.isEmpty ? .secondary : .primary)
                .lineLimit(settings.largeControls ? 4 : 3)
                .frame(
                    maxWidth: .infinity,
                    minHeight: settings.largeControls ? 84 : 64,
                    alignment: .topLeading
                )
                .textSelection(.enabled)
        }
        .panelStyle(highContrast: settings.highContrast)
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType =
            UIImagePickerController.isSourceTypeAvailable(.camera)
            ? .camera : .photoLibrary
        picker.mediaTypes = ["public.image"]
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate,
        UIImagePickerControllerDelegate
    {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction)
        {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController
                .InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImagePicked(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

#Preview {
    CameraView(searchText: .constant(""), selectedTab: .constant(.camera))
        .environment(AppSettingsViewModel())
}
