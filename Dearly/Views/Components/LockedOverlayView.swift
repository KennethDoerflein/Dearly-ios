import SwiftUI

struct LockedOverlayView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    var body: some View {
        ZStack {
            // Dark Overlay
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white, .blue)
                    .symbolRenderingMode(.palette)
                
                VStack(spacing: 8) {
                    Text("Subscription Required")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    
                    Text("You have reached your Free tier limit. Please upgrade to Premium to unlock unlimited cards and continue using the app.")
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Button(action: {
                    Task {
                        try? await SuperwallService.shared.triggerPaywall(event: "onboarding_complete")
                    }
                }) {
                    Text("Subscribe Now")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.top, 16)
            }
        }
    }
}
