//
//  RootView.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import SwiftUI

struct RootView: View {

    @State private var settings = AppSettingsViewModel()
    @State private var selectedTab = AppTab.translate
    @State private var searchText = ""

    var body: some View {

        TabView(selection: $selectedTab) {

            Tab(
                settings.text("tab.translate"),
                systemImage: "translate",
                value: .translate
            ) {
                TranslatorView(searchText: $searchText)
            }

            Tab(
                settings.text("tab.camera"),
                systemImage: "camera",
                value: .camera
            ) {
                CameraView(searchText: $searchText, selectedTab: $selectedTab)
            }

            Tab(
                settings.text("tab.live"),
                systemImage: "airpods.pro",
                value: .live
            ) {
                LiveTranslationView()
            }

            Tab(
                settings.text("tab.settings"),
                systemImage: "gear",
                value: .settings
            ) {
                SettingsView()
            }
        }
        .environment(settings)
        .preferredColorScheme(settings.preferredColorScheme)
        .tint(settings.colorTint)
        .fullScreenCover(isPresented: onboardingBinding) {
            OnboardingView {
                settings.hasCompletedOnboarding = true
            }
            .environment(settings)
            .interactiveDismissDisabled()
        }
    }

    private var onboardingBinding: Binding<Bool> {

        Binding {
            !settings.hasCompletedOnboarding
        } set: { isPresented in
            if !isPresented {
                settings.hasCompletedOnboarding = true
            }
        }
    }
}

enum AppTab: Hashable {

    case translate
    case camera
    case live
    case settings
}

#Preview {
    RootView()
}
