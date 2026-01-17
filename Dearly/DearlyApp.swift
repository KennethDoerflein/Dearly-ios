//
//  DearlyApp.swift
//  Dearly
//
//  Created by Mark Mauro on 10/27/25.
//

import SwiftUI
import SwiftData
import SuperwallKit

@main
struct DearlyApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    init() {
        // Configure Superwall SDK
        Superwall.configure(apiKey: "pk_qgy7lKimDkwfz7eHprOZq")
        
        // Clean up legacy UserDefaults data from old storage system
        clearLegacyUserDefaultsData()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    HomeView()
                } else {
                    OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
                }
            }
            .onOpenURL { url in
                handleOpenURL(url)
            }
        }
        .modelContainer(for: Card.self)
    }
    
    private func handleOpenURL(_ url: URL) {
        // Check if it's a .dearly file
        if url.pathExtension.lowercased() == "dearly" {
            // Post notification for HomeView to handle the import (it has access to modelContext)
            NotificationCenter.default.post(
                name: .dearlyFileOpened,
                object: nil,
                userInfo: ["url": url]
            )
        } else {
            // Handle deep links with Superwall
            Superwall.handleDeepLink(url)
        }
    }
    
    /// Removes old UserDefaults data that was used before SwiftData migration
    private func clearLegacyUserDefaultsData() {
        let legacyKey = "savedCards"
        if UserDefaults.standard.data(forKey: legacyKey) != nil {
            UserDefaults.standard.removeObject(forKey: legacyKey)
            print("✅ Cleared legacy UserDefaults card data")
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let dearlyFileOpened = Notification.Name("dearlyFileOpened")
}

