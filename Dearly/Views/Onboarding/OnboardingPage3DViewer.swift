//
//  OnboardingPage3DViewer.swift
//  Dearly
//
//  Created by Mark Mauro on 2/12/26.
//

import SwiftUI

struct OnboardingPage3DViewer: View {
    @Binding var currentPage: Int
    @State private var rotationY: Double = -15
    @State private var floatOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // 3D Card visual
            ZStack {
                // Soft glow
                Circle()
                    .fill(Color(red: 0.95, green: 0.88, blue: 0.88).opacity(0.5))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                
                // Floating card with 3D rotation
                ZStack {
                    // Card shadow
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.06))
                        .frame(width: 140, height: 190)
                        .offset(y: 10)
                        .blur(radius: 16)
                    
                    // Main card
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.99, blue: 0.97),
                                    Color(red: 0.99, green: 0.96, blue: 0.94)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 190)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color(red: 0.92, green: 0.87, blue: 0.85), lineWidth: 1)
                        )
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 32))
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
                                
                                Text("With Love")
                                    .font(.custom("Snell Roundhand", size: 18))
                                    .foregroundColor(Color(red: 0.50, green: 0.40, blue: 0.40))
                            }
                        )
                }
                .rotation3DEffect(.degrees(rotationY), axis: (x: 0.05, y: 1, z: 0), perspective: 0.5)
                .offset(y: floatOffset)
                
                // Gesture hints
                VStack(spacing: 4) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.55).opacity(0.5))
                    Text("Tap")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.55))
                }
                .offset(x: -105, y: 50)
                
                VStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.55).opacity(0.5))
                    Text("Zoom")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.55))
                }
                .offset(x: 105, y: 50)
                
                VStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 18))
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.55).opacity(0.5))
                    Text("Flip")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(Color(red: 0.65, green: 0.55, blue: 0.55))
                }
                .offset(x: 0, y: -110)
            }
            .frame(height: 260)
            .padding(.bottom, 20)
            
            // Title
            Text("Dearly")
                .font(.custom("Snell Roundhand", size: 52))
                .foregroundColor(Color(red: 0.35, green: 0.28, blue: 0.28))
            
            Text("Relive Every Detail")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(Color(red: 0.55, green: 0.48, blue: 0.48))
                .padding(.top, 4)
            
            Spacer()
            
            // Description
            Text("Open, flip, and zoom into your cards\nwith our immersive 3D viewer.\nEvery handwritten word, perfectly preserved.")
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
                    currentPage = 3
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
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                rotationY = 15
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                floatOffset = -10
            }
        }
    }
}

#Preview {
    ZStack {
        Color(red: 1.0, green: 0.97, blue: 0.95).ignoresSafeArea()
        OnboardingPage3DViewer(currentPage: .constant(2))
    }
}
