import SwiftUI
import Combine
import SuperwallKit

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var currentSubscription: UserSubscription = .defaultSubscription
    @Published var isLocked: Bool = false
    @Published var isTrialActive: Bool = false
    
    // Backward compatibility for existing views that observed isPremium directly.
    @Published var isPremium: Bool = false
    
    // Constants for Keychain
    private let service = "com.dearly.subscription"
    private let account = "user"
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadSubscription()
        
        // Listen to SuperwallService updates
        SuperwallService.shared.statusSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleStatusChange(status)
            }
            .store(in: &cancellables)
            
        // Setup initial status
        handleStatusChange(Superwall.shared.subscriptionStatus)
    }
    
    // MARK: - Persistence
    
    private func loadSubscription() {
        if let saved = KeychainHelper.shared.read(service: service, account: account, type: UserSubscription.self) {
            self.currentSubscription = saved
            self.isPremium = (saved.tier == .premium)
            if saved.tier == .locked {
                self.isLocked = true
            }
            print("💎 SubscriptionManager: Loaded subscription with tier \(saved.tier)")
        } else {
            self.currentSubscription = .defaultSubscription
            print("💎 SubscriptionManager: No saved subscription, using default.")
        }
    }
    
    private func saveSubscription() {
        KeychainHelper.shared.save(currentSubscription, service: service, account: account)
    }
    
    // MARK: - State Management
    
    private func handleStatusChange(_ status: SubscriptionStatus) {
        let wasPremium = (currentSubscription.tier == .premium)
        let isNowPremium = status.isActive
        
        if isNowPremium {
            currentSubscription.tier = .premium
            isLocked = false // Upgrade unlocks immediately
            
            if !wasPremium {
                currentSubscription.subscriptionStartDate = Date()
            }
        } else {
            // Downgrade to Free unless they were already locked
            if currentSubscription.tier != .locked {
                currentSubscription.tier = .free
            }
        }
        
        isPremium = isNowPremium
        saveSubscription()
        
        Task {
            await updateTrialState()
        }
    }
    
    // MARK: - Gating and Limits
    
    func canAccess(feature: Feature) -> Bool {
        return SubscriptionAccess.canAccessFeature(subscription: currentSubscription, feature: feature)
    }
    
    func getLimit(for limit: Limit) -> Int {
        return SubscriptionAccess.getSubscriptionLimit(subscription: currentSubscription, limit: limit)
    }
    
    /// Use this to update lock state based on active usage
    func evaluateLockState(currentUsage: Int) {
        let maxAllowed = getLimit(for: .maxCards)
        
        if currentSubscription.tier == .free && currentUsage > maxAllowed {
            isLocked = true
            currentSubscription.tier = .locked
            saveSubscription()
        } else if currentSubscription.tier == .locked && currentUsage <= maxAllowed {
            isLocked = false
            currentSubscription.tier = .free
            saveSubscription()
        }
    }
    
    /// Backward compatibility check limit when attempting to add a new card
    func canAddCard(currentCount: Int) -> Bool {
        return currentCount < getLimit(for: .maxCards)
    }
    
    // MARK: - Paywall variable parsing
    
    private func updateTrialState() async {
        guard currentSubscription.tier == .premium else {
            isTrialActive = false
            return
        }
        
        do {
            // Use standard Superwall shared instance to get paywall silently to grab configurations in background
            _ = try await Superwall.shared.getPaywall(forEvent: "onboarding_complete")
            
            // If the user upgraded recently and hasn't passed 7 days (mock length), it's considered local trial
            if let start = currentSubscription.subscriptionStartDate,
               let daysSinceStart = Calendar.current.dateComponents([.day], from: start, to: Date()).day {
                self.isTrialActive = daysSinceStart <= 7
            } else {
                self.isTrialActive = false
            }
        } catch {
            self.isTrialActive = false
        }
    }
}
