//
//  AppVisualStyles.swift
//  Ikonlate
//
//  Created by Tufan Cakir on 30.06.26.
//

import SwiftUI

extension View {

    func panelStyle(highContrast: Bool = false) -> some View {
        padding(16)
            .background(
                highContrast ? .regularMaterial : .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        highContrast
                            ? Color.primary.opacity(0.35)
                            : Color.white.opacity(0.35),
                        lineWidth: highContrast ? 1.5 : 1
                    )
            }
    }

    @ViewBuilder
    func translatorSymbolEffect(isActive: Bool, reduceAnimations: Bool)
        -> some View
    {
        if reduceAnimations {
            self
        } else {
            symbolEffect(.pulse, options: .repeat(.continuous), value: isActive)
        }
    }
}

struct GlassmorphismBackground: View {

    let highContrast: Bool
    let reduceAnimations: Bool

    @State private var animate = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {

        ZStack {

            baseGradient
            colorField

            LinearGradient(

                colors: [
                    .white.opacity(colorScheme == .dark ? 0.06 : 0.28),
                    .clear,
                    .black.opacity(colorScheme == .dark ? 0.26 : 0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Rectangle()
                .fill(.ultraThinMaterial.opacity(highContrast ? 0.55 : 0.22))
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceAnimations else { return }

            withAnimation(
                .easeInOut(duration: 9).repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }

    private var baseGradient: some View {

        LinearGradient(

            colors: highContrast
                ? [
                    Color(.systemBackground),
                    Color(.secondarySystemBackground),
                ]
                : [
                    Color(red: 0.10, green: 0.13, blue: 0.22),
                    Color(red: 0.13, green: 0.20, blue: 0.34),
                    Color(red: 0.07, green: 0.12, blue: 0.17),
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var colorField: some View {

        ZStack {

            Circle()
                .fill(.cyan.opacity(highContrast ? 0.08 : 0.34))
                .frame(width: 320, height: 320)
                .blur(radius: 48)
                .offset(x: animate ? -122 : -82, y: animate ? -248 : -206)

            Circle()
                .fill(.indigo.opacity(highContrast ? 0.10 : 0.42))
                .frame(width: 360, height: 360)
                .blur(radius: 58)
                .offset(x: animate ? 164 : 118, y: animate ? -52 : -12)

            Circle()
                .fill(.orange.opacity(highContrast ? 0.06 : 0.28))
                .frame(width: 280, height: 280)
                .blur(radius: 54)
                .offset(x: animate ? 132 : 86, y: animate ? 284 : 236)

            Circle()
                .fill(.mint.opacity(highContrast ? 0.06 : 0.24))
                .frame(width: 240, height: 240)
                .blur(radius: 44)
                .offset(x: animate ? -162 : -126, y: animate ? 196 : 246)
        }
    }
}
