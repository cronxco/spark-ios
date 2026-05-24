import SwiftUI

public extension View {
    /// Applies the standard Spark text-field input background: thin material
    /// with a subtle primary-tinted stroke border.
    func textFieldInputBackground() -> some View {
        background {
            RoundedRectangle(cornerRadius: SparkRadii.sm)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: SparkRadii.sm)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
    }
}
