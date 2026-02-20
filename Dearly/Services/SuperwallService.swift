import Foundation
import SuperwallKit
import Combine

@MainActor
class SuperwallService: NSObject, SuperwallDelegate {
    static let shared = SuperwallService()
    
    // Publishers for SubscriptionManager
    let statusSubject = PassthroughSubject<SubscriptionStatus, Never>()
    
    override private init() {
        super.init()
    }
    
    // MARK: - Initialization
    
    func configure(apiKey: String) {
        Superwall.configure(apiKey: apiKey)
        Superwall.shared.delegate = self
    }
    
    // MARK: - SuperwallDelegate
    
    func subscriptionStatusDidChange(to newValue: SubscriptionStatus) {
        print("💎 SuperwallService: subscriptionStatusDidChange to \(newValue)")
        statusSubject.send(newValue)
    }
    
    // MARK: - Paywall Trigger
    
    /// Triggers a Superwall paywall placement
    func triggerPaywall(event: String, params: [String: Any]? = nil) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let handler = PaywallPresentationHandler()
            
            handler.onPresent { paywallInfo in
                print("Paywall onPresent: \(paywallInfo.name)")
            }
            handler.onDismiss { paywallInfo in
                print("Paywall onDismiss: \(paywallInfo.name)")
                continuation.resume(returning: ())
            }
            handler.onError { error in
                print("Paywall onError: \(error.localizedDescription)")
                continuation.resume(throwing: error)
            }
            handler.onSkip { skipReason in
                print("Paywall onSkip: \(skipReason)")
                continuation.resume(returning: ())
            }
            
            Superwall.shared.register(event: event, params: params, handler: handler)
        }
    }
}
