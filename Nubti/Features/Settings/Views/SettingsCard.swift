import SwiftUI

/// SettingsCardView
/// صف إعدادات بتصميم موحد، يمكن إعادة استخدامه في كامل التطبيق.
struct SettingsCardView: View {

    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var trailing: String? = nil // جعلها اختيارية مع قيمة افتراضية
    var trailingColor: Color = .secondary

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 16) {

            // 1. الأيقونة داخل حاوية ملونة
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 42, height: 42)
                .background(
                    iconColor.opacity(colorScheme == .dark ? 0.12 : 0.15)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)

            // 2. النصوص
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 3. العنصر الجانبي (نص أو سهم)
            if let trailing = trailing {
                Text(trailing)
                    .font(.system(.caption, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(trailingColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(trailingColor.opacity(0.12))
                    .clipShape(Capsule())
            } else {
                // سهم التوجيه الافتراضي
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.5))
                    // ✅ دعم الاتجاه في اللغة العربية
                    .flipsForRightToLeftLayoutDirection(true)
            }
        }
        // ✅ التنسيق الموحد (Inline Style) لضمان العمل بدون extensions خارجية
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Accessibility Helper

    private var accessibilityText: String {
        if let trailing = trailing {
            return "\(title), \(subtitle), \(trailing)"
        } else {
            return "\(title), \(subtitle)"
        }
    }
}

// MARK: - Previews

#Preview("With Trailing Text") {
    SettingsCardView(
        icon: "bell.fill",
        iconColor: .blue,
        title: "Notifications",
        subtitle: "Manage your alerts",
        trailing: "ON",
        trailingColor: .green
    )
    .padding()
}

#Preview("With Arrow") {
    SettingsCardView(
        icon: "globe",
        iconColor: .purple,
        title: "Language",
        subtitle: "English"
    )
    .padding()
}

#Preview("Arabic RTL") {
    SettingsCardView(
        icon: "calendar",
        iconColor: .orange,
        title: "الإشعارات",
        subtitle: "إدارة التنبيهات",
        trailing: "مفعل",
        trailingColor: .green
    )
    .padding()
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("Dark Mode") {
    SettingsCardView(
        icon: "moon.fill",
        iconColor: .indigo,
        title: "Appearance",
        subtitle: "Dark mode enabled"
    )
    .padding()
    .preferredColorScheme(.dark)
}
