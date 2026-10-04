import SparkKit
import SparkUI
import SwiftUI

/// Soft delete with Undo for a detail screen (EOB-D5).
///
/// Asks before deleting, then covers the detail with a "deleted" state and
/// shows an Undo toast. When the toast times out the screen pops back, except
/// under VoiceOver, where the deleted state (with its own Undo) stays until
/// the user leaves.
struct DeleteWithUndoModifier: ViewModifier {
    let noun: String
    let isDeleted: Bool
    @Binding var isConfirming: Bool
    let delete: @MainActor () async throws -> Void
    let restore: @MainActor () async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var showToast = false
    @State private var toastGeneration = 0
    @State private var isWorking = false
    @State private var errorMessage: String?

    private static let toastDuration: Duration = .seconds(6)

    func body(content: Content) -> some View {
        content
            .overlay {
                if isDeleted {
                    deletedState
                }
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    UndoToast("\(noun.capitalized) deleted", isWorking: isWorking) {
                        Task { await performRestore() }
                    }
                    .padding(.horizontal, SparkSpacing.lg)
                    .padding(.bottom, SparkSpacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task(id: toastGeneration) {
                guard showToast else { return }
                try? await Task.sleep(for: Self.toastDuration)
                guard !Task.isCancelled, showToast else { return }
                withAnimation { showToast = false }
                if !voiceOverEnabled {
                    dismiss()
                }
            }
            .confirmationDialog("Delete this \(noun)?", isPresented: $isConfirming, titleVisibility: .visible) {
                Button("Delete \(noun)", role: .destructive) {
                    Task { await performDelete() }
                }
            } message: {
                Text("You can undo this straight away.")
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Please try again.")
            }
    }

    private var deletedState: some View {
        VStack {
            EmptyState(
                systemImage: "trash",
                title: "\(noun.capitalized) deleted",
                message: "Changed your mind? Undo brings it back.",
                actionTitle: "Undo"
            ) {
                Task { await performRestore() }
            }
            .padding(SparkSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.sparkSurface.ignoresSafeArea())
    }

    private func performDelete() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await delete()
            withAnimation { showToast = true }
            toastGeneration += 1
        } catch {
            SparkObservability.captureHandled(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't delete this \(noun)."
        }
    }

    private func performRestore() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await restore()
            withAnimation { showToast = false }
            toastGeneration += 1
        } catch {
            SparkObservability.captureHandled(error)
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't bring this \(noun) back."
        }
    }
}

extension View {
    func sparkDeleteWithUndo(
        noun: String,
        isDeleted: Bool,
        isConfirming: Binding<Bool>,
        delete: @escaping @MainActor () async throws -> Void,
        restore: @escaping @MainActor () async throws -> Void
    ) -> some View {
        modifier(DeleteWithUndoModifier(noun: noun, isDeleted: isDeleted, isConfirming: isConfirming, delete: delete, restore: restore))
    }
}

enum EntityDeleteError: LocalizedError {
    case changedElsewhere

    var errorDescription: String? {
        "This changed since you opened it, so it wasn't deleted. Check it and try again."
    }
}
