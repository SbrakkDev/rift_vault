//
//  RiftVaultTests.swift
//  RiftVaultTests
//
//  Created by Davide Busà on 29/11/25.
//

import Testing
@testable import RiftVault

struct RiftVaultTests {

    @Test func validatesSampleDeck() async throws {
        let deck = SampleVaultData.decks[0]
        let issues = DeckValidator.validate(deck: deck, catalog: SampleVaultData.catalog)
        #expect(issues.isEmpty)
    }

    @Test func catchesWrongMainDeckSize() async throws {
        var deck = SampleVaultData.decks[0]
        deck.entries.removeAll { $0.slot == .main && $0.cardID == "mind_15" }
        let issues = DeckValidator.validate(deck: deck, catalog: SampleVaultData.catalog)
        #expect(issues.contains(where: { $0.message.contains("40 carte") }))
    }

}
