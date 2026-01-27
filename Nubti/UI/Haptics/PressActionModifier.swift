import SwiftUI

struct PressActionModifier: ViewModifier {

    let onPress: () -> Void
    let onRelease: () -> Void

    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        if isPressed {
                            isPressed = false
                            onRelease()
                        }
                    }
            )
    }
}

extension View {

    func pressAction(
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void
    ) -> some View {
        modifier(
            PressActionModifier(
                onPress: onPress,
                onRelease: onRelease
            )
        )
    }
}
