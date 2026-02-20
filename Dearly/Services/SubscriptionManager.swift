//
//  SubscriptionManager.swift
//  Dearly
//
//  Wraps Superwall's subscription status into a reactive isPremium flag
//  used throughout the app for feature gating.
//

import SwiftUI
import Combine
import SuperwallKit

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isPremium: Bool = false
    
    static let freeCardLimit = 2
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        let initialStatus = Superwall.shared.subscriptionStatus
        isPremium = initialStatus.isActive
        print("💎 SubscriptionManager init — status: \(initialStatus), isPremium: \(initialStatus.isActive)")
        
        Superwall.shared.$subscriptionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                let newValue = status.isActive
                print("💎 SubscriptionManager status changed — status: \(status), isPremium: \(newValue)")
                self?.isPremium = newValue
            }
            .store(in: &cancellables)
    }
    
    /// Whether the user can add another card given their current count.
    func canAddCard(currentCount: Int) -> Bool {
        isPremium || currentCount < SubscriptionManager.freeCardLimit
    }
}
