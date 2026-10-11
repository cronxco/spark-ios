import Foundation
import Testing

@testable import SparkKit

private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(type, from: Data(json.utf8))
}

@Suite("Money plan contract")
struct MoneyPlanContractTests {
    @Test("the plan decodes cover, budgets, pots and interest")
    func plan() throws {
        let response = try decode(MoneyPlanResponse.self, """
        {"data":{
          "safe_to_spend":{"available":250000,"owed_on_cards":50000,"amount":200000},
          "cover":{"pot":{"id":"p1","name":"Pot of Requirement","balance":40000},
                   "cards":[{"id":"c1","name":"Amex","since":"2026-10-02","owed":50000,"buffered":20000,"transactions":4}],
                   "owed":50000,"buffered":20000,"unbuffered":30000,"status":"short","shortfall":10000},
          "budgets":[{"id":"b1","name":"Eating out","limit":25000,"spent":26000,"remaining":-1000,"ratio":1.04,
                      "expected_ratio":0.6,"status":"over","categories":["eating_out"],"people":[]}],
          "strip":{"in_pots":10000000,"latest_month":"2026-10","latest_interest":29490,"run_rate":353880,
                   "twelve_months":29490,"months_recorded":1,"tax_estimate":141552,"as_of":"2026-10-05"},
          "pots":[{"id":"p1","name":"Gift","balance":10000000,"goal":null,"interest":29200,"aer":0.034,"share":0.99}],
          "interest":[{"month":"2026-10","total":29490,"pots":2,"estimated":false,
                       "lines":[{"pot":"Gift","amount":29200,"estimated":false,"aer":0.034}]}],
          "buffer_enabled":false}}
        """)
        #expect(response.data.safeToSpend.amount == 200_000)
        #expect(response.data.cover.status == .short)
        #expect(response.data.cover.cards.first?.buffered == 20_000)
        #expect(response.data.budgets.first?.status == .over)
        #expect(response.data.pots.first?.goal == nil)
        #expect(response.data.interest.first?.lines.first?.pot == "Gift")
        #expect(response.data.bufferEnabled == false)
    }

    @Test("a plan without a buffer pot decodes")
    func noBuffer() throws {
        let response = try decode(MoneyPlanResponse.self, """
        {"data":{"safe_to_spend":{"available":0,"owed_on_cards":0,"amount":0},
          "cover":{"pot":null,"cards":[],"owed":0,"buffered":0,"unbuffered":0,"status":"no_buffer","shortfall":0},
          "budgets":[],"strip":{"in_pots":0,"latest_month":null,"latest_interest":0,"run_rate":0,"twelve_months":0,
          "months_recorded":0,"tax_estimate":0,"as_of":"2026-10-05"},"pots":[],"interest":[],"buffer_enabled":true}}
        """)
        #expect(response.data.cover.pot == nil)
        #expect(response.data.cover.status == .noBuffer)
    }

    @Test("spending marks which transactions can go to the buffer")
    func spending() throws {
        let response = try decode(SpendingResponse.self, """
        {"data":{"month":"2026-10","total":5500,"transactions":[
          {"id":"e1","time":"2026-10-10T12:00:00+00:00","amount":4000,"merchant":"Hotel","category":"holidays",
           "account_id":"c1","account":"Amex","person":null,"source":"gocardless","pending":false,"budget_id":null,"buffer":null},
          {"id":"e2","time":"2026-10-09T12:00:00+00:00","amount":1500,"merchant":"Pret","category":"eating_out",
           "account_id":"m1","account":"Monzo","person":"Will","source":"monzo","pending":false,"budget_id":"b1","buffer":null},
          {"id":"e3","time":"2026-10-08T12:00:00+00:00","amount":2000,"merchant":"Flights","category":"holidays",
           "account_id":"c1","account":"Amex","person":null,"source":"gocardless","pending":false,"budget_id":null,"buffer":"linked"},
          {"id":"e4","time":"2026-10-07T12:00:00+00:00","amount":-500,"merchant":"Refund","category":"general",
           "account_id":"c1","account":"Amex","person":null,"source":"gocardless","pending":false,"budget_id":null,"buffer":null}]}}
        """)
        let flags = response.data.transactions.map(\.canAddToBuffer)
        #expect(flags == [true, false, false, false])
    }

    @Test("the plan and spending endpoints")
    func plainEndpoints() {
        #expect(MoneyEndpoint.plan().path == "/money/plan")
        #expect(MoneyEndpoint.spending().query.isEmpty)
        #expect(MoneyEndpoint.spending(month: "2026-10").query == [URLQueryItem(name: "month", value: "2026-10")])
    }

    @Test("adding to the buffer sends the confirmed total with an idempotency key")
    func addToBuffer() throws {
        let key = UUID()
        let endpoint = MoneyEndpoint.addToBuffer(eventIds: ["e1", "e3"], confirmedTotal: 6000, idempotencyKey: key)
        #expect(endpoint.path == "/money/buffer")
        #expect(endpoint.headers["Idempotency-Key"] == key.uuidString)
        let body = try #require(endpoint.body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["event_ids"] as? [String] == ["e1", "e3"])
        #expect(json["confirmed_total"] as? Int == 6000)
    }

    @Test("a preview sends no total and no key")
    func preview() throws {
        let endpoint = MoneyEndpoint.previewBuffer(eventIds: ["e1"])
        #expect(endpoint.path == "/money/buffer/preview")
        let body = try #require(endpoint.body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["confirmed_total"] == nil)
        #expect(endpoint.headers["Idempotency-Key"] == nil)
    }

    @Test("marking the buffer pot sends the flag")
    func bufferPot() throws {
        let endpoint = MoneyEndpoint.setCardBuffer(potId: "p1", enabled: true)
        #expect(endpoint.path == "/money/pots/p1")
        let body = try #require(endpoint.body)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["card_buffer"] as? Bool == true)
    }
}
