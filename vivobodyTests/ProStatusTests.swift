//
//  ProStatusTests.swift
//  vivobodyTests
//
//  Guards the pure entitlement + gating rules in ProGate: how a
//  StoreKit transaction's facts resolve to a ProStatus, and the
//  free-tier template limit (5 free, unlimited on Pro, creation-only
//  gating so over-limit libraries stay usable).
//

import Testing
@testable import vivobody

struct ProStatusTests {

    // MARK: - Entitlement resolution

    @Test func noPurchaseResolvesFree() {
        #expect(ProGate.status(hasVerifiedPurchase: false, isRevoked: false) == .free)
    }

    @Test func verifiedPurchaseResolvesPro() {
        #expect(ProGate.status(hasVerifiedPurchase: true, isRevoked: false) == .pro)
    }

    @Test func revokedPurchaseResolvesFree() {
        #expect(ProGate.status(hasVerifiedPurchase: true, isRevoked: true) == .free)
    }

    @Test func revocationWithoutPurchaseResolvesFree() {
        #expect(ProGate.status(hasVerifiedPurchase: false, isRevoked: true) == .free)
    }

    // MARK: - Template limit

    @Test func freeTierIncludesFiveTemplates() {
        #expect(ProGate.freeTemplateLimit == 5)
    }

    @Test func freeUnderLimitCanCreate() {
        for count in 0..<ProGate.freeTemplateLimit {
            #expect(ProGate.canCreateTemplate(existingCount: count, status: .free))
        }
    }

    @Test func freeAtLimitCannotCreate() {
        #expect(!ProGate.canCreateTemplate(existingCount: 5, status: .free))
    }

    @Test func freeOverLimitCannotCreate() {
        // Refund edge case: existing templates stay usable, but
        // creating more stays gated.
        #expect(!ProGate.canCreateTemplate(existingCount: 6, status: .free))
    }

    @Test func proIsUnlimited() {
        #expect(ProGate.canCreateTemplate(existingCount: 5, status: .pro))
        #expect(ProGate.canCreateTemplate(existingCount: 500, status: .pro))
    }
}
