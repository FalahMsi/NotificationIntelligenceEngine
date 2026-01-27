import SwiftUI

struct ManualLeavesSettingsLink: View {
    @EnvironmentObject private var settings: UserSettingsStore
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        NavigationLink {
            // الوجهة: الحاوية الرئيسية للإجازات
            ManualLeavesRootView()
        } label: {
            HStack(spacing: 16) {
                
                // 1. الأيقونة
                Image(systemName: "doc.text.badge.plus") // أيقونة أنسب للسجلات والإضافة
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                    .frame(width: 42, height: 42)
                    .background(
                        ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.1 : 0.15)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // 2. النصوص المترجمة
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("سجل الإجازات", "Leaves Log"))
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(tr("الدورية، المرضية، الطارئة، والراحات", "Annual, Sick, Emergency, and Rest days"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 3. أيقونة التوجيه
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary.opacity(colorScheme == .dark ? 0.5 : 0.8))
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("سجل الإجازات", "Leaves Log"))
    }
}
