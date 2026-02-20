import SwiftUI

struct PaywallModifier: ViewModifier {
    @Binding var isPresented: Bool
    let event: String
    let onDismiss: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented) { newValue in
                if newValue {
                    Task {
                        do {
                            try await SuperwallService.shared.triggerPaywall(event: event)
                            DispatchQueue.main.async {
                                self.isPresented = false
                                self.onDismiss?()
                            }
                        } catch {
                            DispatchQueue.main.async {
                                self.isPresented = false
                            }
                        }
                    }
                }
            }
    }
}

extension View {
    func paywallTrigger(
        isPresented: Binding<Bool>,
        event: String = "onboarding_complete",
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        self.modifier(PaywallModifier(isPresented: isPresented, event: event, onDismiss: onDismiss))
    }
}
