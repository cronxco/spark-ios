import Foundation
import Testing

@testable import SparkKit

@Suite("Block details")
struct BlockDetailsTests {
    private func decode(_ json: String) throws -> Block {
        try JSONDecoder().decode(Block.self, from: Data(json.utf8))
    }

    @Test("the plugin's name, glyph, domain and flags decode")
    func presentationFields() throws {
        let block = try decode("""
        {"id":"1","block_type":"merchant","title":"Pret","display_name":"Merchant","icon":"fas.store",
         "domain":"money","ai_written":false,"hidden":true,
         "details":{"merchant":"Pret","category":"eating_out","address":"1 High St"}}
        """)

        #expect(block.displayName == "Merchant")
        #expect(block.icon == "fas.store")
        #expect(block.domain == "money")
        #expect(block.aiWritten == false)
        #expect(block.hidden)
        #expect(block.details?.string("merchant") == "Pret")
    }

    @Test("an older server's block decodes with nothing new set")
    func olderServer() throws {
        let block = try decode(#"{"id":"1","block_type":"merchant","title":"Pret"}"#)

        #expect(block.displayName == nil)
        #expect(block.aiWritten == nil)
        #expect(!block.hidden)
        #expect(block.details == nil)
        #expect(block.facts.isEmpty)
        #expect(!block.isRecord)
    }

    @Test("details that aren't an object are ignored, not a decoding failure")
    func emptyDetailsArray() throws {
        let block = try decode(#"{"id":"1","block_type":"merchant","title":"Pret","details":[]}"#)
        #expect(block.details == nil)
    }

    @Test("a merchant reads its category in words and its address")
    func merchantFacts() throws {
        let block = try decode("""
        {"id":"1","block_type":"merchant","title":"Pret","details":{"category":"eating_out","address":"1 High St"}}
        """)

        #expect(block.facts == [BlockFact("Category", "Eating out"), BlockFact("Address", "1 High St")])
        #expect(block.isRecord)
    }

    @Test("a set reads set, reps, weight with its unit and RPE")
    func exerciseFacts() throws {
        let block = try decode("""
        {"id":"1","block_type":"exercise","title":"Bench","details":{"set_number":2,"reps":8,"weight":60,"unit":"kg","rpe":7.5}}
        """)

        #expect(block.facts.map(\.label) == ["Set", "Reps", "Weight", "RPE"])
        #expect(block.facts.first { $0.label == "Weight" }?.value.hasSuffix(" kg") == true)
        #expect(!block.isRecord, "Sets stay tiles; there are many to a workout")
    }

    @Test("a track's length is minutes and seconds")
    func trackLength() throws {
        let block = try decode("""
        {"id":"1","block_type":"track_details","title":"Song","details":{"album":"LP","artists":["A","B"],"duration_ms":222000}}
        """)

        #expect(block.facts == [BlockFact("Album", "LP"), BlockFact("Artists", "A, B"), BlockFact("Length", "3:42")])
    }

    @Test("a payment method masks the card to its last four")
    func paymentMethod() throws {
        let block = try decode("""
        {"id":"1","block_type":"receipt_payment_method","title":"Paid","details":{"payment_method":"contactless","card_last_4":"4242"}}
        """)

        #expect(block.facts == [BlockFact("Paid by", "Contactless"), BlockFact("Card", "•••• 4242")])
    }

    @Test("receipt money is formatted in the block's currency")
    func receiptMoney() throws {
        let block = try decode("""
        {"id":"1","block_type":"receipt_tax_summary","title":"VAT","details":{"subtotal":10,"tax_rate":20,"currency":"EUR"}}
        """)
        let subtotal = block.facts.first { $0.label == "Subtotal" }?.value

        #expect(subtotal == 10.0.formatted(.currency(code: "EUR")))
        #expect(block.facts.first { $0.label == "Tax" }?.value == "20%")
    }

    @Test("a brewery joins its locality and region")
    func breweryPlace() throws {
        let block = try decode("""
        {"id":"1","block_type":"brewery_details","title":"Brew","details":{"locality":"Leeds","region":"West Yorkshire"}}
        """)

        #expect(block.facts == [BlockFact("From", "Leeds, West Yorkshire")])
    }
}
