import SparkKit
import SparkUI
import SwiftUI

struct CheckInModalView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    let slot: String
    let date: Date

    @State private var selectedMood: String?
    @State private var selectedTags: Set<String> = []
    @State private var note: String = ""
    @State private var isLogging = false
    @State private var logError: String?

    private let moods: [(String, Color)] = [
        ("exhausted", Color.sparkError),
        ("tired",     Color.sparkWarning),
        ("ok",        Color(red: 0.6, green: 0.6, blue: 0.65)),
        ("rested",    Color.sparkSuccess),
        ("great",     Color.sparkAccent),
    ]

    private let defaultTags = ["restless", "dreams", "headache", "energised", "stressed", "calm"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SparkSpacing.xl) {
                    moodSection
                    tagsSection
                    noteSection
                    if let err = logError {
                        Text(err)
                            .font(SparkTypography.bodySmall)
                            .foregroundStyle(Color.sparkError)
                    }
                }
                .padding(.horizontal, SparkSpacing.lg)
                .padding(.vertical, SparkSpacing.xl)
            }
            .scrollContentBackground(.hidden)
            .background(Color.sparkSurface.ignoresSafeArea())
            .navigationTitle("\(slot.capitalized) check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log it") {
                        Task { await logCheckIn() }
                    }
                    .disabled(selectedMood == nil || isLogging)
                    .bold()
                }
            }
        }
    }

    // MARK: - Sections

    private var moodSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SectionLabel("MOOD")
            HStack(spacing: SparkSpacing.sm) {
                ForEach(moods, id: \.0) { mood, color in
                    MoodChip(
                        label: mood,
                        color: color,
                        isSelected: selectedMood == mood
                    ) {
                        selectedMood = selectedMood == mood ? nil : mood
                    }
                }
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            SectionLabel("CONTEXT")
            FlowLayout(spacing: SparkSpacing.sm) {
                ForEach(defaultTags, id: \.self) { tag in
                    SelectableTagChip(tag: tag, isSelected: selectedTags.contains(tag)) {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                    }
                }
            }
        }
    }

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: SparkSpacing.md) {
            HStack {
                SectionLabel("NOTE")
                Spacer()
                Text("\(note.count) / 500")
                    .font(SparkTypography.monoSmall)
                    .foregroundStyle(.secondary)
            }
            TextEditor(text: Binding(
                get: { note },
                set: { note = String($0.prefix(500)) }
            ))
            .font(SparkTypography.body)
            .frame(minHeight: 100, maxHeight: 200)
            .scrollContentBackground(.hidden)
            .padding(SparkSpacing.md)
            .sparkGlass(.roundedRect(SparkRadii.md))
        }
    }

    // MARK: - Actions

    private func logCheckIn() async {
        guard let mood = selectedMood else { return }
        isLogging = true
        defer { isLogging = false }

        let entry = CheckIn(
            slot: slot,
            mood: mood,
            tags: Array(selectedTags),
            note: note.isEmpty ? nil : note,
            loggedAt: .now
        )

        // Persist locally first (optimistic)
        persistLocally(entry)

        // POST to backend (best-effort)
        _ = try? await appModel.apiClient.request(CheckInsEndpoint.create(entry))

        dismiss()
    }

    private func persistLocally(_ entry: CheckIn) {
        let defaults = UserDefaults(suiteName: "group.co.cronx.spark")
        let dateKey = Self.dateKey(date)
        let storageKey = "checkin_\(dateKey)_\(slot)"
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entry) {
            defaults?.set(data, forKey: storageKey)
        }
    }

    private static func dateKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}

// MARK: - Components

private struct MoodChip: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(SparkTypography.monoSmall)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, SparkSpacing.md)
                .padding(.vertical, SparkSpacing.sm)
                .background(isSelected ? color : color.opacity(0.12))
                .clipShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mood: \(label)\(isSelected ? ", selected" : "")")
    }
}

private struct SelectableTagChip: View {
    let tag: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("#\(tag)")
                .font(SparkTypography.monoSmall)
                .foregroundStyle(isSelected ? Color.sparkAccent : .primary)
                .padding(.horizontal, SparkSpacing.md - 2)
                .padding(.vertical, SparkSpacing.xs + 1)
                .background(
                    isSelected
                        ? Color.sparkAccent.opacity(0.15)
                        : Color.primary.opacity(0.06)
                )
                .clipShape(.capsule)
                .overlay {
                    if isSelected {
                        Capsule().strokeBorder(Color.sparkAccent.opacity(0.5), lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tag \(tag)\(isSelected ? ", selected" : "")")
    }
}
