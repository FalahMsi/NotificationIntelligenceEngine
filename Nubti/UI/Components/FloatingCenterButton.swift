import SwiftUI

/// FloatingCenterButton
/// الزر المركزي العائم (زر التقويم الرئيسي).
/// تم التدقيق: دعم كامل للترجمة، ألوان متكيفة مع النظام، وتفاعل لمسي ممتاز.
struct FloatingCenterButton: View {

    // MARK: - Inputs
    let isSelected: Bool
    let currentSystem: ShiftSystemID
    let action: () -> Void

    // MARK: - State
    @State private var isPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Body
    var body: some View {
        Button {
            action()
        } label: {
            ZStack {
                // 1. الخلفية المتدرجة (Gradient Background)
                Circle()
                    .fill(buttonGradient)
                    .frame(
                        width: ShiftTheme.Layout.floatingButtonSize,
                        height: ShiftTheme.Layout.floatingButtonSize
                    )
                    // ظل ذكي يتكيف مع الوضع النهاري والليلي
                    .shadow(
                        color: colorScheme == .dark ? shadowColor : Color.black.opacity(0.15),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                    // حلقة بيضاء للتمييز عند التحديد
                    .overlay(
                        Circle()
                            .strokeBorder(
                                isSelected ? Color.white.opacity(0.9) : Color.clear,
                                lineWidth: 2.5
                            )
                    )
                    // إطار خفيف جداً لتحديد الحواف في الوضع النهاري
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0 : 0.2), lineWidth: 1)
                    )

                // 2. أيقونة التقويم
                Image(systemName: "calendar")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        // تفاعل لمسي مخصص
        .pressAction(
            onPress: {
                isPressed = true
                HapticManager.shared.impact(.medium)
            },
            onRelease: {
                isPressed = false
            }
        )
        // دعم الوصول (Accessibility)
        .accessibilityLabel(tr("التقويم", "Calendar"))
        .accessibilityHint(tr("الانتقال إلى عرض التقويم", "Go to calendar view"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Styling Logic

    private var buttonGradient: LinearGradient {
        var colors: [Color] = []
        
        if currentSystem == .standardMorning {
            // تدرج دافئ للنظام الصباحي (برتقالي -> أحمر)
            colors = [.orange, .red.opacity(colorScheme == .dark ? 0.8 : 0.9)]
        } else {
            // تدرج الهوية الباردة للنوبات (أزرق -> نيلي)
            colors = [
                ShiftTheme.ColorToken.brandPrimary,
                ShiftTheme.ColorToken.brandInfo
            ]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shadowColor: Color {
        if currentSystem == .standardMorning {
            return Color.orange.opacity(0.4)
        } else {
            return ShiftTheme.ColorToken.brandPrimary.opacity(0.4)
        }
    }
}

// MARK: - Previews

#Preview("Shift System - Selected") {
    FloatingCenterButton(isSelected: true, currentSystem: .threeShiftTwoOff) {}
        .padding()
}

#Preview("Morning System") {
    FloatingCenterButton(isSelected: false, currentSystem: .standardMorning) {}
        .padding()
}

#Preview("Dark Mode") {
    FloatingCenterButton(isSelected: true, currentSystem: .threeShiftTwoOff) {}
        .padding()
        .preferredColorScheme(.dark)
}
