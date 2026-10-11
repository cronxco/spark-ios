import SparkUI
import SwiftUI

extension View {
    /// Form rows sit on a material over the app background, not the system grouped grey.
    func glassRows() -> some View {
        listRowBackground(Rectangle().fill(.ultraThinMaterial))
    }

    /// Puts a `Form` on the app background with the Knowledge accent.
    func editorSurface() -> some View {
        tint(Color.domainKnowledge)
            .scrollContentBackground(.hidden)
            .sparkAppBackground()
    }
}
