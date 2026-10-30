import Foundation
import Testing

@testable import SparkKit

@Suite("Block values")
struct BlockValueTests {
    private func block(_ type: String, value: String?, unit: String?) -> Block {
        Block(id: "b", blockType: type, title: "T", value: value, unit: unit)
    }

    @Test("durations read as hours and minutes, never raw seconds")
    func durations() {
        #expect(BlockValue.duration(seconds: 28_500) == "7h 55m")
        #expect(BlockValue.duration(seconds: 7_200) == "2h")
        #expect(BlockValue.duration(seconds: 2_520) == "42m")
        #expect(BlockValue.duration(seconds: 65) == "1m 05s")
        #expect(BlockValue.duration(seconds: 120) == "2m")
        #expect(BlockValue.duration(seconds: 45) == "45s")
        #expect(BlockValue.duration(seconds: 0) == "0s")
    }

    @Test("second and minute units become one duration string with no unit")
    func durationUnits() {
        let sleep = block("sleep_stage", value: "28500", unit: "seconds").displayValue
        #expect(sleep?.text == "7h 55m")
        #expect(sleep?.unit == nil)

        let workout = block("duration", value: "42", unit: "min").displayValue
        #expect(workout?.text == "42m")
    }

    /// The backend uses `m` for metres, so it must not read as minutes.
    @Test("metres are not minutes")
    func metres() {
        let distance = block("distance", value: "5000", unit: "m").displayValue
        #expect(distance?.text == "5,000")
        #expect(distance?.unit == "m")
    }

    @Test("percentages and energy scores carry a maximum, other numbers don't")
    func maximums() {
        let contributor = block("contributor", value: "88", unit: "percent").displayValue
        #expect(contributor?.maximum == 100)
        #expect(contributor?.unit == "%")
        #expect(contributor?.fraction == 0.88)

        let energy = block("mental_energy", value: "4", unit: nil).displayValue
        #expect(energy?.maximum == 5)

        let heartRate = block("heart_rate", value: "58", unit: "bpm").displayValue
        #expect(heartRate?.maximum == nil)
        #expect(heartRate?.fraction == nil)
    }

    @Test("fractions are clamped")
    func clamped() {
        #expect(block("contributor", value: "130", unit: "%").displayValue?.fraction == 1)
    }

    @Test("text values pass through and blank values are nil")
    func passthrough() {
        #expect(block("merchant", value: "Pret", unit: nil).displayValue?.text == "Pret")
        #expect(block("merchant", value: "  ", unit: nil).displayValue == nil)
        #expect(block("merchant", value: nil, unit: nil).displayValue == nil)
    }
}
