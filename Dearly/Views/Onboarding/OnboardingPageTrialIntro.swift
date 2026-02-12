//
//  OnboardingPageTrialIntro.swift
//  Dearly
//
//  Created by Mark Mauro on 2/12/26.
//

import SwiftUI

struct OnboardingPageTrialIntro: View {
    @Binding var currentPage: Int
    @State private var shimmerOffset: CGFloat = -200
    
    private let roseColor = Color(red: 0.85, green: 0.55, blue: 0.55)
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Premium gift icon
            ZStack {
                Circle()
                    .fill(Color(red: 0.95, green: 0.88, blue: 0.88).opacity(0.5))
                    .frame(width: 160, height: 160)
                    .blur(radius: 35)
                
                Image(systemName: "sparkles")
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
            }
            .padding(.bottom, 32)
            
            // Title
            Text("Experience Dearly Premium")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.35, green: 0.28, blue: 0.28))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("Free for 7 Days")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(roseColor)
                .padding(.top, 6)
            
            Spacer()
            
            // What you get — premium features list
            VStack(alignment: .leading, spacing: 18) {
                TrialFeatureRow(icon: "infinity", text: "Unlimited card storage")
                TrialFeatureRow(icon: "cube.transparent", text: "Beautiful 3D card viewer")
                TrialFeatureRow(icon: "heart.fill", text: "Favorite & organize your collection")
                TrialFeatureRow(icon: "icloud.fill", text: "Automatic cloud backup")
            }
            .padding(.horizontal, 44)
            
            Spacer()
            
            // Button — just advances, NOT the paywall
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                withAnimation(.spring(response: 0.4)) {
                    currentPage = 7
                }
            }) {
                Text("Continue")
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
    }
}

// MARK: - Trial Feature Row

struct TrialFeatureRow: View {
    let icon: String
    let text: String
    
    private let roseColor = Color(red: 0.85, green: 0.55, blue: 0.55)
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(roseColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(roseColor)
            }
            
            Text(text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.35, green: 0.30, blue: 0.30))
        }
    }
}

#Preview {
    ZStack {
        Color(red: 1.0, green: 0.97, blue: 0.95).ignoresSafeArea()
        OnboardingPageTrialIntro(currentPage: .constant(6))
    }
}
