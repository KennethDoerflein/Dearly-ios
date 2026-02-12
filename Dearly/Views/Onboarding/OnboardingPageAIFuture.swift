//
//  OnboardingPageAIFuture.swift
//  Dearly
//
//  Created by Mark Mauro on 2/12/26.
//

import SwiftUI

struct OnboardingPageAIFuture: View {
    @Binding var currentPage: Int
    
    private let mauveColor = Color(red: 0.68, green: 0.45, blue: 0.55)
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Robot icon
            RobotIcon(color: mauveColor)
                .padding(.bottom, 32)
            
            // Title — unique style for this "coming soon" page
            Text("Coming Soon: The AI Future")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 0.35, green: 0.28, blue: 0.28))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // 2x2 Feature grid
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    AIFeatureCard(icon: "magnifyingglass", title: "Sentiment\nAnalysis", color: mauveColor)
                    AIFeatureCard(icon: "tag.fill", title: "Smart\nTagging", color: mauveColor)
                }
                HStack(spacing: 16) {
                    AIFeatureCard(icon: "square.stack.3d.up.fill", title: "Multi-Surface\nContext", color: mauveColor)
                    AIFeatureCard(icon: "sparkles", title: "Memory\nInsights", color: mauveColor)
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Button — advances to trial intro
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                withAnimation(.spring(response: 0.4)) {
                    currentPage = 6
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

// MARK: - Robot Icon (matches mockup)

struct RobotIcon: View {
    let color: Color
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(color.opacity(0.08))
                .frame(width: 150, height: 150)
            
            VStack(spacing: 0) {
                // Antenna
                VStack(spacing: 0) {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: 4, height: 14)
                }
                
                // Head with ears
                ZStack {
                    // Main head
                    RoundedRectangle(cornerRadius: 18)
                        .fill(color)
                        .frame(width: 76, height: 66)
                    
                    // Eyes
                    HStack(spacing: 16) {
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                        Circle()
                            .fill(.white)
                            .frame(width: 16, height: 16)
                    }
                    .offset(y: -8)
                    
                    // Mouth (grid pattern)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 32, height: 14)
                        .overlay(
                            HStack(spacing: 0) {
                                ForEach(0..<3, id: \.self) { i in
                                    if i > 0 {
                                        Rectangle()
                                            .fill(color.opacity(0.35))
                                            .frame(width: 1)
                                    }
                                    Color.clear
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        )
                        .offset(y: 12)
                    
                    // Left ear
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 10, height: 22)
                        .offset(x: -43)
                    
                    // Right ear
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 10, height: 22)
                        .offset(x: 43)
                }
            }
        }
    }
}

// MARK: - AI Feature Card

struct AIFeatureCard: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
            
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 0.35, green: 0.30, blue: 0.30))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: color.opacity(0.1), radius: 10, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(color.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color(red: 1.0, green: 0.97, blue: 0.95).ignoresSafeArea()
        OnboardingPageAIFuture(currentPage: .constant(5))
    }
}
