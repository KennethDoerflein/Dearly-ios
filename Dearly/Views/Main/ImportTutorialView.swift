//
//  ImportTutorialView.swift
//  Dearly
//
//  Step-by-step tutorial for importing backups from iCloud
//

import SwiftUI

struct ImportTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to Restore Your Cards")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.25))
                    
                    Text("Follow these steps to restore your card collection from iCloud backup.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
                
                // Steps
                VStack(alignment: .leading, spacing: 24) {
                    TutorialStepView(
                        number: 1,
                        title: "Back Up Your Cards",
                        description: "First, make sure you have a backup. Go to Settings and tap \"Back Up Now\" to save your cards to iCloud.",
                        systemImage: "icloud.and.arrow.up.fill",
                        iconColor: Color(red: 0.75, green: 0.55, blue: 0.5)
                    )
                    
                    TutorialStepView(
                        number: 2,
                        title: "Your Backup is in iCloud",
                        description: "Your backup is automatically saved to iCloud Drive in the \"Dearly\" folder. You can see it in the Files app.",
                        systemImage: "folder.fill",
                        iconColor: Color(red: 0.4, green: 0.6, blue: 0.8)
                    )
                    
                    TutorialStepView(
                        number: 3,
                        title: "Restore on Any Device",
                        description: "Sign in with the same Apple ID on your new device, then tap \"Restore from Backup\" in Settings to recover all your cards.",
                        systemImage: "arrow.clockwise.icloud.fill",
                        iconColor: Color(red: 0.5, green: 0.75, blue: 0.6)
                    )
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // Tips Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tips")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.25))
                    
                    TipView(
                        icon: "wifi",
                        text: "Make sure you're connected to Wi-Fi for faster backups"
                    )
                    
                    TipView(
                        icon: "clock",
                        text: "Backups may take a moment to sync to iCloud"
                    )
                    
                    TipView(
                        icon: "person.crop.circle",
                        text: "Use the same Apple ID to access your backup on other devices"
                    )
                    
                    TipView(
                        icon: "arrow.triangle.2.circlepath",
                        text: "Restore won't duplicate cards - existing cards are skipped"
                    )
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // FAQ Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Frequently Asked Questions")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.4, green: 0.3, blue: 0.25))
                    
                    FAQItemView(
                        question: "Will restoring delete my existing cards?",
                        answer: "No, by default restore only adds cards that don't already exist. You can choose to replace all cards if needed."
                    )
                    
                    FAQItemView(
                        question: "How often should I backup?",
                        answer: "We recommend backing up after adding new cards, especially sentimental ones. A weekly backup is a good habit."
                    )
                    
                    FAQItemView(
                        question: "Where is my backup stored?",
                        answer: "Your backup is stored in iCloud Drive under the \"Dearly\" folder. You can view it in the Files app on any device signed into your Apple ID."
                    )
                    
                    FAQItemView(
                        question: "What if iCloud isn't available?",
                        answer: "Make sure you're signed into iCloud in your device Settings, and that iCloud Drive is enabled."
                    )
                }
                
                Spacer(minLength: 40)
            }
            .padding(24)
        }
        .background(Color(red: 0.98, green: 0.97, blue: 0.95))
        .navigationTitle("Import Guide")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.light)
    }
}

// MARK: - Tutorial Step View

struct TutorialStepView: View {
    let number: Int
    let title: String
    let description: String
    let systemImage: String
    let iconColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number circle
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("Step \(number)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(iconColor)
                        .textCase(.uppercase)
                    
                    Spacer()
                }
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color(red: 0.3, green: 0.25, blue: 0.2))
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Tip View

struct TipView: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(Color(red: 0.75, green: 0.55, blue: 0.5))
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - FAQ Item View

struct FAQItemView: View {
    let question: String
    let answer: String
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(red: 0.3, green: 0.25, blue: 0.2))
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if isExpanded {
                Text(answer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        ImportTutorialView()
    }
}
