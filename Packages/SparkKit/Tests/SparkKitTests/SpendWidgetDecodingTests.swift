import Foundation
import Testing
@testable import SparkKit

@Suite("Spend widget decoding")
struct SpendWidgetDecodingTests {
    @Test("decodes production merchant amount payload")
    func decodesProductionMerchantAmountPayload() throws {
        let json = """
        {
          "currency": "GBP",
          "date": "2026-05-06",
          "top_merchants": [
            {
              "amount": 407023.43,
              "name": "2026-05-06"
            },
            {
              "amount": 5.59,
              "name": "Daybridge"
            }
          ],
          "total": 407031.95,
          "transaction_count": 65,
          "unit": "GBP"
        }
        """

        let widget = try JSONDecoder().decode(SpendWidget.self, from: Data(json.utf8))

        #expect(widget.currency == "GBP")
        #expect(widget.total == 407031.95)
        #expect(widget.transactionCount == 65)
        #expect(widget.topMerchants.count == 2)
        #expect(widget.topMerchants[0].name == "2026-05-06")
        #expect(widget.topMerchants[0].total == 407023.43)
        #expect(widget.topMerchants[0].count == nil)
    }

    @Test("still decodes legacy merchant total and count payload")
    func decodesLegacyMerchantTotalPayload() throws {
        let json = """
        {
          "currency": "GBP",
          "date": "2026-05-06",
          "top_merchants": [
            {
              "count": 2,
              "name": "Coffee",
              "total": 8.4
            }
          ],
          "total": 8.4,
          "transaction_count": 2,
          "unit": "GBP"
        }
        """

        let widget = try JSONDecoder().decode(SpendWidget.self, from: Data(json.utf8))

        #expect(widget.topMerchants[0].total == 8.4)
        #expect(widget.topMerchants[0].count == 2)
    }
}
