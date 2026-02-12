//
//  OnboardingPageCloudSync.swift
//  Dearly
//
//  Created by Mark Mauro on 2/12/26.
//

import SwiftUI

struct OnboardingPageCloudSync: View {
    @Binding var currentPage: Int
    @State private var syncRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Cloud illustration
            ZStack {
                // Soft glow
                Circle()
                    .fill(Color(red: 0.95, green: 0.88, blue: 0.88).opacity(0.5))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                
                // Connecting lines (subtle)
                Path { path in
                    path.move(to: CGPoint(x: -50, y: 20))
                    path.addLine(to: CGPoint(x: -100, y: 40))
                }
                .stroke(Color(red: 0.85, green: 0.55, blue: 0.55).opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: 200, height: 80)
                
                Path { path in
                    path.move(to: CGPoint(x: 150, y: 20))
                    path.addLine(to: CGPoint(x: 200, y: 40))
                }
                .stroke(Color(red: 0.85, green: 0.55, blue: 0.55).opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: 200, height: 80)
                
                // Cloud with shield
                ZStack {
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 80))
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
                        .shadow(color: Color(red: 0.85, green: 0.50, blue: 0.50).opacity(0.25), radius: 20, y: 10)
                    
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                        .offset(y: 4)
                }
                .scaleEffect(pulseScale)
                
                // Device icons
                VStack(spacing: 4) {
                    Image(systemName: "iphone")
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.55).opacity(0.6))
                    
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.55).opacity(0.4))
                        .rotationEffect(.degrees(syncRotation))
                }
                .offset(x: -100, y: 20)
                
                VStack(spacing: 4) {
                    Image(systemName: "ipad.landscape")
                        .font(.system(size: 24))
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.55).opacity(0.6))
                    
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.55).opacity(0.4))
                        .rotationEffect(.degrees(syncRotation))
                }
                .offset(x: 100, y: 20)
            }
            .frame(height: 200)
            .padding(.bottom, 40)
            
            // Title
            Text("Dearly")
                .font(.custom("Snell Roundhand", size: 52))
                .foregroundColor(Color(red: 0.35, green: 0.28, blue: 0.28))
            
            Text("Safe & Synced")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.55, green: 0.48, blue: 0.48))
                .padding(.top, 4)
            
            Spacer()
            
            // Description
            Text("Your cards are automatically backed up\nto iCloud and synced across all your devices.\nYour memories are always safe.")
                .font(.system(size: 18, weight: .regular, design: .rounded))
                .foregroundColor(Color(red: 0.45, green: 0.40, blue: 0.40))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Button
            Button(action: {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                withAnimation(.spring(response: 0.4)) {
                    currentPage = 5
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
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                syncRotation = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.05
            }
        }
    }
}

#Preview {
    ZStack {
        Color(red: 1.0, green: 0.97, blue: 0.95).ignoresSafeArea()
        OnboardingPageCloudSync(currentPage: .constant(4))
    }
}
