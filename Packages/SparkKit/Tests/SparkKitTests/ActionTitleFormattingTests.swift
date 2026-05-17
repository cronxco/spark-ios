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
