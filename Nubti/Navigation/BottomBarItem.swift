import SwiftUI

/// BottomBarItem
/// عنصر تنقل سفلي ثابت الأبعاد وفق تصميم موحد.
/// الأبعاد (64x44) متوافقة مع كثافة الأيقونات وعدد العناصر في Bottom Bar.
struct BottomBarItem: View {

    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            VStack(spacing: UI.spacing) {
                Image(systemName: isSelected ? "\(icon).fill" : icon)
                    .font(UI.iconFont)
                    .foregroundColor(isSelected ? UI.selectedColor : UI.unselectedColor)
                    // إضافة حركة بسيطة عند الاختيار
                    .scaleEffect(isSelected ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                Text(title)
                    .font(UI.titleFont)
                    .fontWeight(isSelected ? .bold : .medium)
                    .foregroundColor(isSelected ? UI.selectedColor : UI.unselectedColor)
            }
            .frame(width: UI.width, height: UI.height)
            .contentShape(Rectangle()) // يضمن أن منطقة اللمس تشمل كامل الإطار
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - UI Constants

private enum UI {
    static let width: CGFloat = 64
    static let height: CGFloat = 44
    static let spacing: CGFloat = 4

    static let iconFont: Font = .system(size: 20, weight: .semibold, design: .rounded)
    static let titleFont: Font = .system(size: 10, weight: .medium, design: .rounded)

    // الربط مع ثيم التطبيق الموحد
    static var selectedColor: Color { ShiftTheme.ColorToken.brandPrimary }
    static var unselectedColor: Color { Color.secondary.opacity(0.8) }
}
