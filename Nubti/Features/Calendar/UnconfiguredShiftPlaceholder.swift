import SwiftUI

struct UnconfiguredShiftPlaceholder: View {
    @EnvironmentObject private var settings: UserSettingsStore
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            
            // MARK: - Status Icon (Warning Glow)
            ZStack {
                Circle()
                    .fill(ShiftTheme.ColorToken.brandWarning.opacity(colorScheme == .dark ? 0.15 : 0.12))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(colorScheme == .dark ? ShiftTheme.ColorToken.brandWarning : .orange)
            }
            .accessibilityHidden(true)

            // MARK: - Message Content
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("نظام الدوام غير مفعل", "Shift System Inactive"))
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(tr("اختر جدول نوباتك ليتم حساب ساعات العمل والإجازات بدقة.", "Select your shift schedule to accurately calculate work hours and leaves."))
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading) // يضمن محاذاة النص حسب الاتجاه
            }

            Spacer()
            
            // MARK: - Action Hint
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(.secondary.opacity(colorScheme == .dark ? 0.5 : 0.8))
                // ✅ عكس اتجاه السهم عند تحويل اللغة
                .flipsForRightToLeftLayoutDirection(true)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ShiftTheme.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ShiftTheme.Radius.md, style: .continuous)
                .stroke(ShiftTheme.ColorToken.brandWarning.opacity(colorScheme == .dark ? 0.3 : 0.5), lineWidth: 1.2)
        )
        .shadow(
            color: colorScheme == .dark ? ShiftTheme.ColorToken.brandWarning.opacity(0.05) : Color.black.opacity(0.05),
            radius: 12, x: 0, y: 4
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tr("نظام الدوام غير محدد، يرجى اختيار جدول نوباتك للمتابعة", "Shift system not set, please select your schedule to continue"))
    }
}
