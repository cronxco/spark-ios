import Foundation
import Testing
@testable import SparkKit

@Suite("Action title formatting")
struct ActionTitleFormattingTests {
    @Test("formats snake case action titles")
    func formatsSnakeCaseActionTitles() {
        #expect("direct_debit".sparkActionTitle == "Direct Debit")
        #expect("card_payment".sparkActionTitle == "Card Payment")
    }

    @Test("lowercases minor words outside first position")
    func lowercasesMinorWordsOutsideFirstPosition() {
        #expect("pot_transfer_to".sparkActionTitle == "Pot Transfer to")
        #expect("transfer_of_money_with_card".sparkActionTitle == "Transfer of Money with Card")
        #expect("to_account".sparkActionTitle == "To Account")
    }
}

@Suite("Sentence case")
struct SparkSentenceCaseTests {
    /// Spark is sentence case throughout, so a raw identifier reaching the
    /// interface is capitalised once and left alone after that.
    @Test("snake and kebab identifiers become one sentence-cased phrase")
    func identifiersBecomeSentenceCase() {
        #expect("sleep_summary".sparkSentenceCase == "Sleep summary")
        #expect("apple-health".sparkSentenceCase == "Apple health")
        #expect("monzo".sparkSentenceCase == "Monzo")
        #expect("outstanding_balance_due".sparkSentenceCase == "Outstanding balance due")
    }

    /// Unlike `sparkActionTitle`, only the first word is capitalised.
    @Test("it is sentence case, not title case")
    func differsFromTitleCase() {
        #expect("morning_check_in".sparkSentenceCase == "Morning check in")
        #expect("morning_check_in".sparkActionTitle == "Morning Check In")
    }

    @Test("already-shouting input is flattened, not preserved")
    func flattensExistingCaps() {
        #expect("SLEEP_SUMMARY".sparkSentenceCase == "Sleep summary")
        #expect("Monzo".sparkSentenceCase == "Monzo")
    }

    @Test("empty and separator-only input stay empty")
    func degenerateInput() {
        #expect("".sparkSentenceCase == "")
        #expect("___".sparkSentenceCase == "")
        #expect("   ".sparkSentenceCase == "")
    }
}

