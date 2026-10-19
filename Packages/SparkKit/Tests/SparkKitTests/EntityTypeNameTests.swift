import Testing
@testable import SparkKit

@Suite("Entity type names")
struct EntityTypeNameTests {
    @Test("known types read as words, not keys")
    func overrides() {
        #expect(EntityTypeName.display(type: "tv_episode", concept: "media") == "TV episode")
        #expect(EntityTypeName.display(type: "newsletter_publication", concept: "publication") == "Newsletter")
    }

    @Test("owner account objects are named by their integration")
    func ownerAccounts() {
        #expect(EntityTypeName.display(type: "manual_log_user", concept: "user") == "Manual log account")
        #expect(EntityTypeName.display(type: "newsletter_user", concept: "user") == "Newsletter account")
        // Slack users are other workspace members, not the owner's account.
        #expect(EntityTypeName.display(type: "slack_user", concept: "user") == "Slack user")
    }

    @Test("other types are sentence case with acronyms kept")
    func fallback() {
        #expect(EntityTypeName.display(type: "day_note", concept: "document") == "Day note")
        #expect(EntityTypeName.display(type: "ai_url_digest", concept: nil) == "AI URL digest")
        #expect(EntityTypeName.display(type: nil, concept: "place") == "Place")
        #expect(EntityTypeName.display(type: nil, concept: nil) == "Object")
    }

    @Test("user objects are the owner unless they're Slack members")
    func accountOwner() {
        #expect(EntityTypeName.isAccountOwner(concept: "user", type: "manual_log_user"))
        #expect(!EntityTypeName.isAccountOwner(concept: "user", type: "slack_user"))
        #expect(!EntityTypeName.isAccountOwner(concept: "person", type: "immich_person"))
    }
}
