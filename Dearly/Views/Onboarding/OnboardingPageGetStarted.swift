//
//  OnboardingPageGetStarted.swift
//  Dearly
//
//  Created by Mark Mauro on 2/15/26.
//

import SwiftUI
import SuperwallKit

struct OnboardingPageGetStarted: View {
    @Binding var currentPage: Int
    @Binding var isOnboardingComplete: Bool
    @State private var heartScale: CGFloat = 1.0
    
    private let roseColor = Color(red: 0.85, green: 0.55, blue: 0.55)
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Heart icon with glow
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.88, blue: 0.88).opacity(0.5))
                    .frame(width: 160, height: 160)
                    .blur(radius: 35)
                
                Image(systemName: "heart.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.92, green: 0.55, blue: 0.55),
                                Color(red: 0.80, green: 0.45, blue: 0.50)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color(red: 0.85, green: 0.50, blue: 0.50).opacity(0.3), radius: 20, y: 10)
                    .scaleEffect(heartScale)
            }
            .padding(.bottom, 40)
            
            // Title
            Text("Ready to Preserve\nYour Memories?")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.35, green: 0.28, blue: 0.28))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
            
            // Subtitle
            Text("Every card tells a story worth keeping.")
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundColor(Color(red: 0.55, green: 0.48, blue: 0.48))
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // CTA — triggers Superwall paywall
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                
                let handler = PaywallPresentationHandler()
                handler.onDismiss { _, _ in
                    isOnboardingComplete = true
                }
                
                Superwall.shared.register(
                    placement: "onboarding_complete",
                    handler: handler
                ) {
                    isOnboardingComplete = true
                }
            }) {
                Text("Get Started")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.88, green: 0.55, blue: 0.55),
                                Color(red: 0.78, green: 0.45, blue: 0.50)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color(red: 0.85, green: 0.50, blue: 0.50).opacity(0.35), radius: 12, y: 6)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 100)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                heartScale = 1.08
            }
        }
    }
}

#Preview {
    ZStack {
        Color(red: 1.0, green: 0.97, blue: 0.95).ignoresSafeArea()
        OnboardingPageGetStarted(currentPage: .constant(5), isOnboardingComplete: .constant(false))
    }
}
