import SwiftUI

struct ManualLeavesSummaryButton: View {
    
    @State private var showSummary = false
    @EnvironmentObject private var settings: UserSettingsStore
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button {
            HapticManager.shared.selection()
            showSummary = true
        } label: {
            HStack(spacing: 16) {
                
                // 1. Icon
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ShiftTheme.ColorToken.brandInfo)
                    .frame(width: 42, height: 42)
                    .background(
                        ShiftTheme.ColorToken.brandInfo.opacity(colorScheme == .dark ? 0.1 : 0.15)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // 2. Text Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(tr("ملخص الإجازات", "Leave Summary"))
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(tr("إحصائيات الأيام والرصيد", "Stats & Balance"))
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 3. Navigation Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary.opacity(colorScheme == .dark ? 0.5 : 0.8))
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSummary) {
            ManualLeavesSummarySheet()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(tr("ملخص الإجازات", "Leave Summary"))
        .accessibilityHint(tr("يعرض إحصائيات ومجموع أيام الإجازات", "Shows statistics and total leave days"))
    }
}
