import SwiftUI

/// ShiftGroupSelectorView
/// مكون شريطي لاختيار مجموعة النوبة (A–F).
/// يعمل مع RTL بدون كسر المحاذاة العربية.
struct ShiftGroupSelectorView: View {

    // MARK: - Environment
    @EnvironmentObject private var settings: UserSettingsStore
    @ObservedObject private var userShift = UserShift.shared
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Layout
    private let height: CGFloat = 50
    private let spacing: CGFloat = 10

    // MARK: - Data
    private let availableGroups: [ShiftType] = [.A, .B, .C, .D, .F]

    // MARK: - Helpers
    private var isRTL: Bool {
        settings.language == .arabic
    }

    // MARK: - Body
    var body: some View {
        VStack(
            alignment: isRTL ? .trailing : .leading,
            spacing: 10
        ) {

            // العنوان
            Text(tr("اختر المجموعة", "Select Group"))
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: isRTL ? .trailing : .leading)
                .padding(.horizontal, 4)

            // أزرار المجموعات (LTR دائماً)
            HStack(spacing: spacing) {
                ForEach(availableGroups, id: \.rawValue) { shift in
                    groupButton(for: shift)
                }
            }
            .environment(\.layoutDirection, .leftToRight) // ✅ فقط للأزرار
        }
        .padding(.vertical, 8)
    }

    // MARK: - Group Button
    private func groupButton(for shift: ShiftType) -> some View {
        let isSelected = userShift.groupSymbol == shift.symbol
        let color = ShiftTheme.groupColor(for: shift.symbol)

        return Button {
            guard !isSelected else { return }
            HapticManager.shared.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                userShift.updateGroupSymbol(shift.symbol)
            }
        } label: {
            Text(shift.symbol)
                .font(.system(.title3, design: .rounded))
                .fontWeight(.black)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .foregroundColor(isSelected ? .white : .primary)
                .background(
                    ZStack {
                        if isSelected {
                            LinearGradient(
                                colors: [
                                    color,
                                    color.opacity(colorScheme == .dark ? 0.7 : 0.85)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.ultraThinMaterial)
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isSelected ? color.opacity(0.6) : Color.primary.opacity(0.1),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
                .shadow(
                    color: isSelected
                        ? color.opacity(colorScheme == .dark ? 0.4 : 0.25)
                        : Color.black.opacity(colorScheme == .dark ? 0 : 0.03),
                    radius: 8,
                    x: 0,
                    y: 4
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(tr("المجموعة", "Group")) \(shift.symbol)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
