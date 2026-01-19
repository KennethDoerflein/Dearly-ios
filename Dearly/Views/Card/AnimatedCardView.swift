//
//  AnimatedCardView.swift
//  Dearly
//
//  Created by Mark Mauro on 10/28/25.
//

import SwiftUI
import SwiftData

struct AnimatedCardView: View {
    let card: Card
    @Binding var resetTrigger: Bool
    @Binding var selectedPage: CardPage
    @Binding var rotateClockwiseTrigger: Bool
    @Binding var rotateCounterClockwiseTrigger: Bool
    
    @State private var isOpen = false
    @State private var xOffset: CGFloat = 0
    
    // 3D rotation state
    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0
    @State private var currentRotationX: Double = 0
    @State private var currentRotationY: Double = 0
    
    // Z-axis rotation for 90° turns (vertical text reading)
    @State private var currentRotationZ: Double = 0
    
    // Zoom and pan state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero
    @State private var pinchLocation: CGPoint = .zero
    @State private var isPinching: Bool = false

    // Single page aspect ratio from front image (width/height of one page)
    private var singlePageAspectRatio: CGFloat {
        if let frontImage = card.frontImage {
            let w = frontImage.size.width
            let h = frontImage.size.height
            if w > 0 && h > 0 {
                return w / h
            }
        }
        // Default: original single page ratio (160/224 ≈ 0.714)
        return 160.0 / 224.0
    }
    
    // Max dimensions to fit on screen
    private let maxCardWidth: CGFloat = 340
    private let maxCardHeight: CGFloat = 280
    
    // Calculate dimensions: card height is constrained, then page width derived from aspect ratio
    private var cardHeight: CGFloat {
        // Check if max height would make the full card too wide
        let pageWidthAtMaxHeight = maxCardHeight * singlePageAspectRatio
        if pageWidthAtMaxHeight * 2 <= maxCardWidth {
            // Fits within width constraint at max height
            return maxCardHeight
        } else {
            // Reduce height to fit width constraint
            let maxPageWidth = maxCardWidth / 2
            return maxPageWidth / singlePageAspectRatio
        }
    }
    
    private var pageWidth: CGFloat {
        return cardHeight * singlePageAspectRatio
    }
    
    private var cardWidth: CGFloat {
        return pageWidth * 2
    }
    private var normalizedRotationY: Double {
        var angle = (currentRotationY + rotationY).truncatingRemainder(dividingBy: 360)
        if angle > 180 { angle -= 360 }
        if angle < -180 { angle += 360 }
        return angle
    }
    private var isFacingFront: Bool { abs(normalizedRotationY) <= 90 }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // MARK: - Back page (right side)
                ZStack {
                    // BACK COVER (outside when closed, visible from behind when open)
                    Group {
                        if let backImage = card.backImage {
                            Image(uiImage: backImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: pageWidth, height: cardHeight)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: pageWidth, height: cardHeight)
                                .overlay(Text("Back").foregroundColor(.white))
                        }
                    }
                    // rotated so it's only visible from behind
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity((isOpen && isFacingFront) ? 0 : 1)
                    .animation((isOpen && isFacingFront) ? nil : .interpolatingSpring(mass: 1.0, stiffness: 100, damping: 15, initialVelocity: 0), value: isOpen) // Instant hide when opening from front, smooth fade when closing
                    
                    // INSIDE RIGHT (visible when open and facing front)
                    Group {
                        if let rightImage = card.insideRightImage {
                            Image(uiImage: rightImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: pageWidth, height: cardHeight)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: pageWidth, height: cardHeight)
                                .overlay(Text("Inside Right").foregroundColor(.black))
                        }
                    }
                    .opacity((isOpen && isFacingFront) ? 1 : 0)
                    .animation((isOpen && isFacingFront) ? nil : .interpolatingSpring(mass: 1.0, stiffness: 100, damping: 15, initialVelocity: 0), value: isOpen) // Instant show when opening from front, smooth fade when closing
                    .rotation3DEffect(
                        .degrees(isOpen ? 0 : 90),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        anchorZ: 0,
                        perspective: 0.4
                    )
                }
                .cornerRadius(4)
                .zIndex(isFacingFront ? 0 : 1)

                // MARK: - Front page (left side)
                ZStack {
                    // FRONT COVER (outside when closed)
                    Group {
                        if let frontImage = card.frontImage {
                            Image(uiImage: frontImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: pageWidth, height: cardHeight)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: pageWidth, height: cardHeight)
                                .overlay(Text("Tap to Open").foregroundColor(.black))
                        }
                    }
                    .opacity((isOpen && isFacingFront) ? 0 : 1)
                    
                    // INSIDE LEFT (visible when open)
                    Group {
                        if let leftImage = card.insideLeftImage {
                            Image(uiImage: leftImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: pageWidth, height: cardHeight)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: pageWidth, height: cardHeight)
                                .overlay(Text("Inside Left").foregroundColor(.black))
                        }
                    }
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity((isOpen && isFacingFront) ? 1 : 0)
                }
                .cornerRadius(4)
                .shadow(
                    color: Color.black.opacity(isOpen ? 0 : 0.12),
                    radius: isOpen ? 0 : 20,
                    x: 0,
                    y: isOpen ? 0 : 10
                )
                .shadow(
                    color: Color.black.opacity(isOpen ? 0 : 0.08),
                    radius: isOpen ? 0 : 8,
                    x: 0,
                    y: isOpen ? 0 : 4
                )
                // same open/close animation you had before
                .rotation3DEffect(
                    .degrees(isOpen ? -180 : 0),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    anchorZ: 0,
                    perspective: 0.4
                )
                .zIndex(isFacingFront ? 1 : 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(x: xOffset)
            // Apply 3D rotation to entire card
            .rotation3DEffect(
                .degrees(currentRotationX + rotationX),
                axis: (x: 1, y: 0, z: 0)
            )
            .rotation3DEffect(
                .degrees(currentRotationY + rotationY),
                axis: (x: 0, y: 1, z: 0)
            )
            // Z-axis rotation for reading vertical text
            .rotationEffect(.degrees(currentRotationZ))
        }
        .frame(width: cardWidth, height: cardHeight)
        // Apply zoom and pan - OUTSIDE the frame so it can expand
        .scaleEffect(scale)
        .offset(x: panOffset.width, y: panOffset.height)
        .gesture(
            // Drag gesture - behavior depends on zoom
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    if scale > 1.0 || isPinching {
                        // Pan when zoomed
                        panOffset = CGSize(
                            width: lastPanOffset.width + value.translation.width,
                            height: lastPanOffset.height + value.translation.height
                        )
                    } else {
                        // Rotate when not zoomed
                        rotationY = Double(value.translation.width) * 0.5
                        rotationX = Double(-value.translation.height) * 0.5
                    }
                }
                .onEnded { _ in
                    if scale > 1.0 || isPinching {
                        // Save pan position
                        lastPanOffset = panOffset
                    } else {
                        // Save rotation position
                        currentRotationX += rotationX
                        currentRotationY += rotationY
                        rotationX = 0
                        rotationY = 0
                    }
                }
        )
        .gesture(
            // Pinch to zoom with focal point
            MagnificationGesture()
                .onChanged { value in
                    isPinching = true
                    
                    let delta = value / lastScale
                    lastScale = value
                    
                    let oldScale = scale
                    let newScale = min(max(scale * delta, 1.0), 5.0) // Limit zoom between 1x and 5x
                    
                    // Calculate focal point adjustment
                    if oldScale != newScale {
                        let scaleDifference = newScale - oldScale
                        
                        // Adjust pan offset to zoom into the pinch location
                        // The pinch location is relative to the card center
                        panOffset.width = lastPanOffset.width - (pinchLocation.x * scaleDifference)
                        panOffset.height = lastPanOffset.height - (pinchLocation.y * scaleDifference)
                        lastPanOffset = panOffset
                    }
                    
                    scale = newScale
                }
                .onEnded { _ in
                    lastScale = 1.0
                    isPinching = false
                    
                    // Reset to 1.0 if close to it
                    if scale < 1.1 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            scale = 1.0
                            panOffset = .zero
                            lastPanOffset = .zero
                        }
                    }
                }
        )
        .onTapGesture(count: 2, perform: {
            // Double tap to reset zoom
            if scale > 1.0 {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    scale = 1.0
                    panOffset = .zero
                    lastPanOffset = .zero
                }
            }
        })
        .gesture(
            // Track pinch location for focal point zoom
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if isPinching {
                        // Update pinch location relative to card center
                        pinchLocation = CGPoint(
                            x: value.location.x - cardWidth / 2,
                            y: value.location.y - cardHeight / 2
                        )
                    }
                }
        )
        .simultaneousGesture(
            // Tap gesture for opening/closing card - works at any zoom
            TapGesture()
                .onEnded {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    
                    withAnimation(
                        .interpolatingSpring(
                            mass: 1.0,
                            stiffness: 100,
                            damping: 15,
                            initialVelocity: 0
                        )
                    ) {
                        isOpen.toggle()
                        xOffset = isOpen ? pageWidth / 2 : 0
                    }
                }
        )
        .onChange(of: resetTrigger) { _ in
            resetCard()
        }
        .onChange(of: selectedPage) { newPage in
            animateToPage(newPage)
        }
        .onChange(of: rotateClockwiseTrigger) { _ in
            rotate90Degrees(clockwise: true)
        }
        .onChange(of: rotateCounterClockwiseTrigger) { _ in
            rotate90Degrees(clockwise: false)
        }
    }
    
    private func rotate90Degrees(clockwise: Bool) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            currentRotationZ += clockwise ? 90 : -90
        }
    }
    
    private func resetCard() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isOpen = false
            xOffset = 0
            rotationX = 0
            rotationY = 0
            currentRotationX = 0
            currentRotationY = 0
            currentRotationZ = 0
            scale = 1.0
            panOffset = .zero
            lastPanOffset = .zero
            lastScale = 1.0
            pinchLocation = .zero
            isPinching = false
        }
    }
    
    private func animateToPage(_ page: CardPage) {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            // Reset zoom/pan first
            scale = 1.0
            panOffset = .zero
            lastPanOffset = .zero
            rotationX = 0
            rotationY = 0
            
            switch page {
            case .front:
                // Show closed card front page (flat, facing forward)
                isOpen = false
                xOffset = 0
                currentRotationY = 0
                currentRotationX = 0
                
            case .back:
                // Show closed card back page (flat, facing forward)
                isOpen = false
                xOffset = 0
                currentRotationY = 180
                currentRotationX = 0
                
            case .insideLeft:
                // Show open card inside left page (flat, facing forward)
                isOpen = true
                xOffset = pageWidth / 2
                currentRotationY = 180 // Show the inside left which faces backward when open
                currentRotationX = 0
                
            case .insideRight:
                // Show open card inside right page (flat, facing forward)
                isOpen = true
                xOffset = pageWidth / 2
                currentRotationY = 0 // Show the inside right which faces forward when open
                currentRotationX = 0
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        AnimatedCardView(
            card: Card(),
            resetTrigger: .constant(false),
            selectedPage: .constant(.front),
            rotateClockwiseTrigger: .constant(false),
            rotateCounterClockwiseTrigger: .constant(false)
        )
        .padding()
    }
    .modelContainer(for: Card.self, inMemory: true)
}
