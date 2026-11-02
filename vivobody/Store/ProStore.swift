//
//  ProStore.swift
//  vivobody
//
//  The StoreKit purchase boundary. Owns the Pro entitlement (one
//  non-consumable lifetime unlock), the purchase and restore flows,
//  and the Transaction.updates listener. The rest of the app reads
//  `appState.pro.status` (or the ProStore environment object) and
//  calls `requestUnlock()` for the paywall.
//
//  Entitlement resolution is local-only: StoreKit 2 verifies the
//  transaction JWS on device, so the check works offline. The last
//  known value is mirrored to UserDefaults so the UI never flashes
//  locked while StoreKit resolves on a cold launch, and to the App
//  Group so widgets can gate without touching StoreKit.
//

import Foundation
import Observation
import StoreKit

/// `pro` is a verified, unrevoked lifetime purchase; everything else
/// is `free`. There is no trial: the free tier itself is the trial.
nonisolated enum ProStatus: Equatable {
    case pro
    case free
}

/// Pure gating rules, kept free of StoreKit.
nonisolated enum ProGate {
    /// How many workout templates the free tier includes. Creating the
    /// next one presents the paywall; templates already over the limit
    /// (after a refund) stay fully usable.
    static let freeTemplateLimit = 5

    static func status(hasVerifiedPurchase: Bool, isRevoked: Bool) -> ProStatus {
        hasVerifiedPurchase && !isRevoked ? .pro : .free
    }

    /// First-frame entitlement before StoreKit settles the receipt.
    /// DEBUG's explicit `--pro` override wins, while `--no-iap` fails
    /// closed because no receipt verification will follow.
    static func launchStatus(
        cachedUnlocked: Bool,
        forcedPro: Bool = false,
        storeKitDisabled: Bool = false
    ) -> ProStatus {
        if forcedPro { return .pro }
        if storeKitDisabled { return .free }
        return cachedUnlocked ? .pro : .free
    }

    static func canCreateTemplate(existingCount: Int, status: ProStatus) -> Bool {
        canCreateTemplates(existingCount: existingCount, adding: 1, status: status)
    }

    /// Capacity is checked for a whole multi-day batch, so a free user
    /// never receives a partially saved week.
    static func canCreateTemplates(
        existingCount: Int,
        adding requestedCount: Int,
        status: ProStatus
    ) -> Bool {
        guard requestedCount >= 0 else { return false }
        if status == .pro { return true }
        return max(0, existingCount) + requestedCount <= freeTemplateLimit
    }
}

/// Why the paywall was presented, so the sheet can lead with "you hit
/// the cap" instead of the generic pitch.
nonisolated enum PaywallContext: Equatable {
    case general
    case templateLimit
}

@MainActor
@Observable
final class ProStore {
    static let productID = "astanciu.vivobody.app.pro.unlock"

    private(set) var status: ProStatus

    /// Held privately so `Product` never leaks past this file; the UI
    /// reads `displayPrice` instead.
    private var product: Product?

    /// Localized price for every paywall surface, never hardcoded. Nil
    /// until the product query returns or while the store is unreachable.
    private(set) var displayPrice: String?

    /// AppRoot binds one sheet to this, so every gate presents the same surface.
    var isPaywallPresented: Bool = false

    /// Reset to `.general` when the sheet comes down, so a stale reason
    /// never leaks into the next presentation.
    var paywallContext: PaywallContext = .general

    /// Purchase or restore failure, surfaced by PaywallSheet.
    /// `.userCancelled` never sets this.
    var purchaseError: String? = nil

    var isUnlocked: Bool {
        status == .pro
    }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    #if DEBUG
        /// `--pro` forces the unlocked state for screenshots and scenarios;
        /// `--no-iap` disables StoreKit and stays free. No-ops in Release.
        @ObservationIgnored private let forcedPro = CommandLine.arguments.contains("--pro")
        @ObservationIgnored private let storeKitDisabled = CommandLine.arguments.contains("--no-iap")
    #endif

    init() {
        let cachedUnlocked = UserDefaults.standard.bool(forKey: SettingsKey.proUnlockedCache)
        #if DEBUG
            status = ProGate.launchStatus(
                cachedUnlocked: cachedUnlocked,
                forcedPro: CommandLine.arguments.contains("--pro"),
                storeKitDisabled: CommandLine.arguments.contains("--no-iap")
            )
            guard !storeKitDisabled else { return }
        #else
            status = ProGate.launchStatus(cachedUnlocked: cachedUnlocked)
        #endif
        updatesTask = Task { [weak self] in
            await self?.listenForTransactionUpdates()
        }
        Task { [weak self] in
            await self?.refreshEntitlements()
            await self?.loadProductIfNeeded()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    /// The single entry point every locked surface calls.
    func requestUnlock(context: PaywallContext = .general) {
        Haptics.soft()
        paywallContext = context
        isPaywallPresented = true
    }

    // MARK: - Entitlement resolution

    /// Settle `status` from the local receipt. Overwrites the launch-time
    /// cache seed in both directions.
    func refreshEntitlements() async {
        #if DEBUG
            guard !storeKitDisabled else { return }
        #endif
        var owned = false
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.productID == Self.productID
            else { continue }
            owned = ProGate.status(
                hasVerifiedPurchase: true,
                isRevoked: transaction.revocationDate != nil
            ) == .pro
        }
        setStatus(owned ? .pro : .free)
    }

    /// Out-of-band transactions: purchases on another device, refunds,
    /// or an Ask to Buy approval that lands after the paywall closed.
    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case let .verified(transaction) = result else { continue }
            if transaction.productID == Self.productID {
                setStatus(ProGate.status(
                    hasVerifiedPurchase: true,
                    isRevoked: transaction.revocationDate != nil
                ))
            }
            await transaction.finish()
        }
    }

    private func setStatus(_ new: ProStatus) {
        #if DEBUG
            if forcedPro { return }
        #endif
        let changed = status != new
        status = new
        UserDefaults.standard.set(new == .pro, forKey: SettingsKey.proUnlockedCache)
        WidgetSnapshotWriter.publishProEntitlement(new == .pro, reload: changed)
    }

    // MARK: - Product

    /// Called at launch and again on every paywall presentation, so a
    /// launch-time failure (offline, store unreachable) heals the next
    /// time the paywall opens. A no-op once the product is loaded.
    func loadProductIfNeeded() async {
        #if DEBUG
            guard !storeKitDisabled else { return }
        #endif
        guard product == nil else { return }
        product = try? await Product.products(for: [Self.productID]).first
        displayPrice = product?.displayPrice
    }

    // MARK: - Purchase / restore

    func purchase() async {
        #if DEBUG
            if storeKitDisabled {
                purchaseError = "In-app purchases are disabled for local testing (--no-iap)."
                return
            }
        #endif
        await loadProductIfNeeded()
        guard let product else {
            purchaseError = "The App Store product couldn't be loaded. Check your connection and try again."
            return
        }
        do {
            switch try await product.purchase() {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    purchaseError = "Your purchase couldn't be verified. Try Restore Purchases."
                    return
                }
                await transaction.finish()
                setStatus(.pro)
            case .userCancelled:
                break
            case .pending:
                // Ask to Buy: the entitlement arrives later through
                // Transaction.updates once approved.
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// App Review requires restore to be reachable from the paywall.
    func restore() async {
        #if DEBUG
            if storeKitDisabled {
                purchaseError = "In-app purchases are disabled for local testing (--no-iap)."
                return
            }
        #endif
        do {
            try await AppStore.sync()
        } catch {
            // A failed sync (offline, cancelled sign-in) is not fatal;
            // resolve from the local receipt instead.
        }
        await refreshEntitlements()
    }
}
