import Foundation

// MARK: - Enums

enum SubscriptionTier: String, Codable {
    case free
    case premium
    case locked
}

enum SubscriptionPlan: String, Codable {
    case weekly
    case monthly
    case yearly
    case lifetime
}

enum Feature: String, Codable, CaseIterable {
    case ocrSearch = "ocr_search"
    case cloudBackup = "cloud_backup"
    case smartCollections = "smart_collections"
    case exportPdf = "export_pdf"
    case timelineReminders = "timeline_reminders"
    case advancedSharing = "advanced_sharing"
    case deleteCards = "delete_cards"
    case aiFeatures = "ai_features"
    case sharingCards = "sharing_cards"
    case multiSelect = "multi_select"
    case importCards = "import_cards"
    case editCards = "edit_cards"
    case readingView = "reading_view"
    case recentlyDeleted = "recently_deleted"
}

enum Limit: String, Codable, CaseIterable {
    case maxCards = "max_cards"
}

// MARK: - Models

struct DeletionQuota: Codable {
    var deletionsThisMonth: Int
    var quotaResetDate: Date?
}

struct UserSubscription: Codable {
    var tier: SubscriptionTier
    var plan: SubscriptionPlan?
    var expiryDate: Date?
    var subscriptionStartDate: Date?
    var isLifetime: Bool
    var deletionQuota: DeletionQuota?
    
    static let defaultSubscription = UserSubscription(
        tier: .free,
        plan: nil,
        expiryDate: nil,
        subscriptionStartDate: nil,
        isLifetime: false,
        deletionQuota: DeletionQuota(deletionsThisMonth: 0, quotaResetDate: nil)
    )
}

// MARK: - Features and Limits Constants

struct SubscriptionAccess {
    static let tierFeatures: [SubscriptionTier: [Feature]] = [
        .locked: [],
        .free: [],
        .premium: [
            .ocrSearch,
            .cloudBackup,
            .smartCollections,
            .exportPdf,
            .timelineReminders,
            .advancedSharing,
            .aiFeatures,
            .sharingCards,
            .multiSelect,
            .importCards,
            .editCards,
            .readingView,
            .recentlyDeleted
        ]
    ]

    static let tierLimits: [SubscriptionTier: [Limit: Int]] = [
        .locked: [.maxCards: 0],
        .free: [.maxCards: 5],
        .premium: [.maxCards: .max] // Using Int.max to represent Infinity
    ]
    
    static func canAccessFeature(subscription: UserSubscription, feature: Feature) -> Bool {
        let features = tierFeatures[subscription.tier] ?? []
        return features.contains(feature)
    }

    static func getSubscriptionLimit(subscription: UserSubscription, limit: Limit) -> Int {
        let limits = tierLimits[subscription.tier] ?? [:]
        return limits[limit] ?? 0
    }
}
