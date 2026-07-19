//
//  ProStore.swift
//  vivobody
//
//  The single StoreKit boundary. Owns the Pro entitlement (one
//  non-consumable lifetime unlock), the purchase / restore flows,
//  and the Transaction.updates listener. Every `import StoreKit` in
//  the app lives in this file — the rest of the codebase reads
//  `appState.pro.status` (or the ProStore environment object) and
//  asks `requestUnlock()` to present the paywall.
//
//  Entitlement resolution is local-only: StoreKit 2 verifies the
//  transaction JWS on device, so there is no server round-trip and
//  the check works offline. The last known value is mirrored to
//  UserDefaults so the UI never flashes locked while StoreKit
//  resolves on a cold launch, and to the App Group so widgets can
//  gate without touching StoreKit.
//

import VivoKit
import Foundation
import Observation
import StoreKit
import WidgetKit

/// The two entitlement states. `pro` is a verified, unrevoked
/// lifetime purchase; everything else is `free`. No trial, no
/// clocks — the free tier itself is the trial.
nonisolated enum ProStatus: Equatable {
    case pro
    case free
}

/// Pure gating rules, kept free of StoreKit so they're unit-testable.
nonisolated enum ProGate {
    /// How many workout templates the free tier includes. Creation of
    /// the next one presents the paywall; templates already over the
    /// limit (refund edge case) stay fully usable.
    static let freeTemplateLimit = 5

    static func status(hasVerifiedPurchase: Bool, isRevoked: Bool) -> ProStatus {
        hasVerifiedPurchase && !isRevoked ? .pro : .free
    }

    /// First-frame entitlement before StoreKit settles the receipt.
    /// A fresh install is free. The cache may preserve a previously
    /// verified purchase across an offline launch; DEBUG's explicit
    /// `--pro` override wins, while `--no-iap` fails closed because no
    /// receipt verification will follow.
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
        status == .pro || existingCount < freeTemplateLimit
    }
}

@MainActor
@Observable
final class ProStore {
    static let productID = "astanciu.vivobody.app.pro.lifetime"

    /// The resolved entitlement. Seeded from the UserDefaults mirror
    /// so the first frame renders correctly, then settled from
    /// `Transaction.currentEntitlements` and kept current by the
    /// updates listener.
    private(set) var status: ProStatus

    /// The loaded App Store product. Held privately so `Product`
    /// (a StoreKit type) never leaks past this file; UI reads
    /// `displayPrice` instead.
    private var product: Product?

    /// Localized price string for every paywall surface — never
    /// hardcoded. Nil until the product query returns (or when the
    /// store is unreachable).
    private(set) var displayPrice: String?

    /// Whether the PaywallSheet is presented. AppRoot binds one sheet
    /// to this, so every gate in the app presents the same surface.
    var isPaywallPresented: Bool = false

    /// Human-readable purchase / restore failure, surfaced as an
    /// alert by PaywallSheet. `.userCancelled` never sets this.
    var purchaseError: String? = nil

    var isUnlocked: Bool { status == .pro }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    #if DEBUG
    /// DEBUG follows the production entitlement path: free until a
    /// verified purchase exists. `--pro` is the sole explicit unlock
    /// override for screenshots and gated-state tests; `--no-iap`
    /// disables StoreKit and deliberately remains free. Both flags are
    /// no-ops in Release.
    @ObservationIgnored private let forcedPro = CommandLine.arguments.contains("--pro")
    @ObservationIgnored private let storeKitDisabled = CommandLine.arguments.contains("--no-iap")
    #endif

    init() {
        let cachedUnlocked = UserDefaults.standard.bool(forKey: SettingsKey.proUnlockedCache)
        #if DEBUG
        let shouldForcePro = CommandLine.arguments.contains("--pro")
        let shouldDisableStoreKit = CommandLine.arguments.contains("--no-iap")
        status = ProGate.launchStatus(
            cachedUnlocked: cachedUnlocked,
            forcedPro: shouldForcePro,
            storeKitDisabled: shouldDisableStoreKit
        )
        #else
        status = ProGate.launchStatus(cachedUnlocked: cachedUnlocked)
        #endif
        #if DEBUG
        guard !storeKitDisabled else { return }
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

    /// Present the paywall. The single entry point every locked
    /// surface calls — quiet, no interstitials anywhere else.
    func requestUnlock() {
        Haptics.soft()
        isPaywallPresented = true
    }

    // MARK: - Entitlement resolution

    /// Settle `status` from the local receipt. Works offline;
    /// overwrites the launch-time cache seed in both directions.
    func refreshEntitlements() async {
        #if DEBUG
        guard !storeKitDisabled else { return }
        #endif
        var owned = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID
            else { continue }
            owned = ProGate.status(
                hasVerifiedPurchase: true,
                isRevoked: transaction.revocationDate != nil
            ) == .pro
        }
        setStatus(owned ? .pro : .free)
    }

    /// Lifetime listener for out-of-band transactions: purchases on
    /// another device, refunds, or an Ask to Buy approval landing
    /// after the paywall was dismissed.
    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            guard case .verified(let transaction) = result else { continue }
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
        UserDefaults(suiteName: WidgetShared.appGroup)?
            .set(new == .pro, forKey: WidgetShared.proUnlockedKey)
        if changed {
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.signatureKind)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetShared.consistencyKind)
        }
    }

    // MARK: - Product

    private func loadProductIfNeeded() async {
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
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseError = "Your purchase couldn't be verified. Try Restore Purchases."
                    return
                }
                await transaction.finish()
                setStatus(.pro)
            case .userCancelled:
                break
            case .pending:
                // Ask to Buy — the entitlement arrives later through
                // Transaction.updates once approved.
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    /// Re-sync with the App Store (App Review requires this to be
    /// reachable from the paywall), then settle the entitlement.
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
            // Sync failing (offline, cancelled sign-in) isn't fatal —
            // fall through and resolve from the local receipt.
        }
        await refreshEntitlements()
    }
}
