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
    
    /// SwiftData model container - configured for LOCAL storage only (no CloudKit sync)
    /// We use iCloud Drive for manual backup instead of automatic CloudKit sync
    let modelContainer: ModelContainer
    
    init() {
        print("🚀 DearlyApp.init - App is starting")
        
        // Create SwiftData container with CloudKit sync ENABLED
        // (Must initialize all stored properties before using self)
        let schema = Schema([Card.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic  // Enable automatic CloudKit sync
        )
        
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ SwiftData container created with CloudKit sync enabled")
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        // Now we can use self - configure Superwall SDK
        Superwall.configure(apiKey: "pk_qgy7lKimDkwfz7eHprOZq")
        
        // Clean up legacy UserDefaults data from old storage system
        clearLegacyUserDefaultsData()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    HomeView()
                        .onAppear {
                            print("🚀 DearlyApp: Showing HomeView (onboarding completed)")
                        }
                } else {
                    OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
                        .onAppear {
                            print("🚀 DearlyApp: Showing OnboardingView (onboarding NOT completed)")
                        }
                }
            }
            .onOpenURL { url in
                handleOpenURL(url)
            }
        }
        .modelContainer(modelContainer)
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

