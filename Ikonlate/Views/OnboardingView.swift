//
//  OnboardingView.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import SwiftUI

struct OnboardingView: View {

    @Environment(AppSettingsViewModel.self) private var settings

    @State private var selectedPage = 0

    let onFinish: () -> Void

    private var pages: [OnboardingPage] {

        [
            OnboardingPage(
                title: settings.text("onboarding.translate.title"),
                message: settings.text("onboarding.translate.message"),
                symbolName: "translate",
                accentColor: .indigo
            ),
            OnboardingPage(
                title: settings.text("onboarding.camera.title"),
                message: settings.text("onboarding.camera.message"),
                symbolName: "camera.viewfinder",
                accentColor: .teal
            ),
            OnboardingPage(
                title: settings.text("onboarding.accessibility.title"),
                message: settings.text("onboarding.accessibility.message"),
                symbolName: "accessibility",
                accentColor: .orange
            ),
        ]
    }

    var body: some View {

        ZStack {
            GlassmorphismBackground(
                highContrast: settings.highContrast,
                reduceAnimations: settings.reduceAnimations
            )

            VStack(spacing: 24) {

                TabView(selection: $selectedPage) {

                    ForEach(Array(pages.enumerated()), id: \.element.id) {
                        index,
                        page in
                        OnboardingPageView(page: page)
                            .tag(index)
                            .padding(.horizontal, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button {
                    if selectedPage < pages.count - 1 {
                        withAnimation(settings.reduceAnimations ? nil : .snappy)
                        {
                            selectedPage += 1
                        }
                    } else {
                        onFinish()
                    }
                } label: {
                    Label(
                        settings.text(
                            selectedPage == pages.count - 1
                                ? "onboarding.button.start"
                                : "onboarding.button.next"
                        ),
                        systemImage: selectedPage == pages.count - 1
                            ? "checkmark.circle.fill"
                            : "arrow.right.circle.fill"
                    )
                    .foregroundStyle(settings.highContrast ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .frame(height: settings.largeControls ? 56 : 50)
                }
                .buttonStyle(.glass)
                .controlSize(settings.largeControls ? .large : .regular)
                .tint(settings.colorTint)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .transaction { transaction in
            if settings.reduceAnimations {
                transaction.animation = nil
            }
        }
    }
}

private struct OnboardingPage: Identifiable {

    let id = UUID()
    let title: String
    let message: String
    let symbolName: String
    let accentColor: Color
}

private struct OnboardingPageView: View {

    let page: OnboardingPage

    @Environment(AppSettingsViewModel.self) private var settings

    var body: some View {

        VStack(spacing: 22) {

            Spacer(minLength: 24)

            Image(systemName: page.symbolName)
                .font(.system(size: settings.largeControls ? 76 : 64))
                .foregroundStyle(page.accentColor)
                .frame(width: 128, height: 128)
                .glassEffect(
                    .regular.tint(page.accentColor.opacity(0.22)),
                    in: .rect(cornerRadius: 28)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 0.5)
                }
                .accessibilityHidden(true)

            VStack(spacing: 12) {

                Text(page.title)
                    .font(
                        settings.largeControls
                            ? .largeTitle.bold() : .title.bold()
                    )
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                Text(page.message)
                    .font(settings.largeControls ? .title3 : .body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .panelStyle(highContrast: settings.highContrast)

            Spacer(minLength: 24)
        }
    }
}

#Preview {
    OnboardingView {}
        .environment(AppSettingsViewModel())
}
