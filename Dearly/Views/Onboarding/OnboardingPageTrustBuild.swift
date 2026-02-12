//
//  OnboardingPageTrustBuild.swift
//  Dearly
//
//  Created by Mark Mauro on 2/12/26.
//

import SwiftUI
import SuperwallKit

struct OnboardingPageTrustBuild: View {
    @Binding var currentPage: Int
    @Binding var isOnboardingComplete: Bool
    @State private var bellBounce: CGFloat = 1.0
    
    private let roseColor = Color(red: 0.85, green: 0.55, blue: 0.55)
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Bell / shield icon
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.88, blue: 0.88).opacity(0.5))
                    .frame(width: 160, height: 160)
                    .blur(radius: 35)
                
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 64))
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
                    .scaleEffect(bellBounce)
            }
            .padding(.bottom, 32)
            
            // Title
            Text("No Surprises, Ever")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.35, green: 0.28, blue: 0.28))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Trust points
            VStack(alignment: .leading, spacing: 24) {
                TrustPointRow(
                    icon: "bell.fill",
                    title: "We'll remind you",
                    subtitle: "Get a notification before your trial ends"
                )
                
                TrustPointRow(
                    icon: "xmark.circle.fill",
                    title: "Cancel anytime",
                    subtitle: "No questions asked, no hassle"
                )
                
                TrustPointRow(
                    icon: "lock.shield.fill",
                    title: "No charge today",
                    subtitle: "You won't be billed until your free trial is over"
                )
            }
            .padding(.horizontal, 44)
            
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
                Text("Start My Free Trial")
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
                bellBounce = 1.08
            }
        }
    }
}

// MARK: - Trust Point Row

struct TrustPointRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    private let roseColor = Color(red: 0.85, green: 0.55, blue: 0.55)
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(roseColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(roseColor)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(red: 0.35, green: 0.28, blue: 0.28))
                
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(Color(red: 0.55, green: 0.48, blue: 0.48))
                    .lineSpacing(2)
            }
        }
    }
}

#Preview {
    ZStack {
        Color(red: 1.0, green: 0.97, blue: 0.95).ignoresSafeArea()
        OnboardingPageTrustBuild(currentPage: .constant(7), isOnboardingComplete: .constant(false))
    }
}
