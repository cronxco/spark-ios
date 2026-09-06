import SparkKit
import SwiftUI

struct EntityEditorSheet: View {
    let title: String
    let initial: [String: String]
    let save: @MainActor ([String: AnyCodable]) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var values: [String: String]
    @State private var error: String?
    @State private var saving = false
    init(title: String, initial: [String: String], save: @escaping @MainActor ([String: AnyCodable]) async throws -> Void) { self.title = title; self.initial = initial; self.save = save; _values = State(initialValue: initial) }
    var body: some View { NavigationStack { Form { ForEach(initial.keys.sorted(), id: \.self) { key in TextField(key.replacingOccurrences(of: "_", with: " ").capitalized, text: Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })) }; if let error { Text(error).foregroundStyle(.red) } }.navigationTitle("Edit \(title)").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await submit() } }.disabled(saving) } } } }
    private func submit() async {
        var changed = [String: AnyCodable]()
        for (key, value) in values where value != initial[key] {
            if key == "url", !value.isEmpty, URL(string: value) == nil { error = "Enter a valid URL."; return }
            if ["value", "value_multiplier"].contains(key), !value.isEmpty, Double(value) == nil { error = "\(key) must be numeric."; return }
            changed[key] = AnyCodable(.string(value))
        }
        guard !changed.isEmpty else { dismiss(); return }
        saving = true
        defer { saving = false }
        do { try await save(changed); dismiss() }
        catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn't save changes." }
    }
}

struct LocationEditorSheet: View {
    let hasLocation: Bool
    let geocode: @MainActor (String) async throws -> Void
    let coordinates: @MainActor (LocationRequest) async throws -> Void
    let clear: @MainActor () async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""; @State private var latitude = ""; @State private var longitude = ""; @State private var error: String?; @State private var saving = false
    var body: some View { NavigationStack { Form { Section("Address") { TextField("Address", text: $address); Button("Find and save address") { Task { await geocodeSave() } }.disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving) }; Section("Coordinates") { TextField("Latitude", text: $latitude).keyboardType(.decimalPad); TextField("Longitude", text: $longitude).keyboardType(.decimalPad); Button("Save coordinates") { Task { await coordinateSave() } }.disabled(saving) }; if hasLocation { Section { Button("Clear location", role: .destructive) { Task { await clearSave() } }.disabled(saving) } }; if let error { Text(error).foregroundStyle(.red) } }.navigationTitle("Edit location").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } } } }
    private func geocodeSave() async { saving = true; defer { saving = false }; do { try await geocode(address.trimmingCharacters(in: .whitespacesAndNewlines)); dismiss() } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn't save location." } }
    private func coordinateSave() async { guard let lat = Double(latitude), let lng = Double(longitude), (-90...90).contains(lat), (-180...180).contains(lng) else { self.error = "Enter valid latitude and longitude."; return }; saving = true; defer { saving = false }; do { try await coordinates(LocationRequest(latitude: lat, longitude: lng, address: address.nilIfEmpty)); dismiss() } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn't save location." } }
    private func clearSave() async { saving = true; defer { saving = false }; do { try await clear(); dismiss() } catch { self.error = (error as? LocalizedError)?.errorDescription ?? "Couldn't clear location." } }
}

private extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }
