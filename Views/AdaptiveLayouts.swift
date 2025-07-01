import SwiftUI

/// Utility view for automatically switching between VStack and HStack based on horizontal size class.
struct AdaptiveStack<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let hAlignment: HorizontalAlignment
    let vAlignment: VerticalAlignment
    let spacing: CGFloat?
    let content: () -> Content

    init(hAlignment: HorizontalAlignment = .center,
         vAlignment: VerticalAlignment = .center,
         spacing: CGFloat? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.hAlignment = hAlignment
        self.vAlignment = vAlignment
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if horizontalSizeClass == .regular {
            HStack(alignment: vAlignment, spacing: spacing, content: content)
        } else {
            VStack(alignment: hAlignment, spacing: spacing, content: content)
        }
    }
}
