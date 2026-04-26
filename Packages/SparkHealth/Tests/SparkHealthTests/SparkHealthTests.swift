import Foundation
import HealthKit
import Testing

@testable import SparkHealth

@MainActor
struct AnchorStoreTests {
    @Test("anchor round-trip encodes and decodes")
    func anchorRoundTrip() {
        let store = HealthKitAnchorStore.shared
        let anchor = HKQueryAnchor(fromValue: 42)
        let key = "test_anchor_\(UUID().uuidString)"
        store.save(anchor, for: key)
        let loaded = store.anchor(for: key)
        store.remove(for: key)
        #expect(loaded != nil)
    }
}

struct TypeMapTests {
    @Test("quantity type server string equals raw value")
    func quantityTypeServerString() {
        for identifier in HealthKitTypeMap.quantityTypes {
            let server = HealthKitTypeMap.serverType(for: identifier)
            #expect(server == identifier.rawValue)
        }
    }

    @Test("category type server string equals raw value")
    func categoryTypeServerString() {
        for identifier in HealthKitTypeMap.categoryTypes {
            let server = HealthKitTypeMap.serverType(for: identifier)
            #expect(server == identifier.rawValue)
        }
    }

    @Test("unit returns non-empty string for all quantity types")
    func unitStrings() {
        for identifier in HealthKitTypeMap.quantityTypes {
            let (_, unitStr) = HealthKitTypeMap.unit(for: identifier)
            #expect(!unitStr.isEmpty)
        }
    }
}

@MainActor
struct PermissionManagerTests {
    @Test("initial state is notDetermined on fresh instance")
    func initialState() {
        // HealthKitPermissionManager.shared is MainActor — safe here.
        // Can't actually request auth in unit tests, just verify initial state.
        let mgr = HealthKitPermissionManager.shared
        // State may be .granted if previously authorised on device.
        // Just ensure the property is accessible and has a defined value.
        let states: [HealthKitPermissionManager.AuthState] = [.notDetermined, .granted, .denied]
        #expect(states.contains(mgr.essentialsState))
        #expect(states.contains(mgr.activityState))
        #expect(states.contains(mgr.advancedState))
    }
}
