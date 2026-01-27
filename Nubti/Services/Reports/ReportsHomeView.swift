import SwiftUI

/// ReportsHomeView (Simplified)
/// شاشة مبسطة للتقارير — نوع واحد فقط (تقرير موحد)
struct ReportsHomeView: View {

    // MARK: - Dependencies
    @EnvironmentObject private var settings: UserSettingsStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ShiftTheme.appBackground
                .ignoresSafeArea()

            VStack(spacing: 32) {

                headerSection

                // Direct navigation to single report type
                NavigationLink {
                    WorkDaysSummarySheet(initialReportMode: .unified)
                } label: {
                    exportCard
                }
                .buttonStyle(.plain)

                infoNote

                Spacer()
            }
            .padding(.top, 24)
            .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
        }
        .navigationTitle(tr("التقارير", "Reports"))
        .navigationBarTitleDisplayMode(.large)
        .environment(\.layoutDirection, settings.language.direction)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {

            Image("Asset")
                .resizable()
                .scaledToFit()
                .frame(width: 70, height: 70)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.15),
                    radius: 14,
                    y: 6
                )

            Text(tr("تصدير التقرير", "Export Report"))
                .font(.system(size: 26, weight: .black, design: .rounded))

            Text(tr(
                "صدّر ملخص الدوام مع ملاحظاتك للفترة المحددة",
                "Export your work summary with notes for the selected period"
            ))
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
        }
    }

    // MARK: - Export Card

    private var exportCard: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        ShiftTheme.ColorToken.brandPrimary.opacity(
                            colorScheme == .dark ? 0.18 : 0.14
                        )
                    )
                    .frame(width: 56, height: 56)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
            }

            // Text
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("تصدير PDF", "Export PDF"))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text(tr("ملخص الدوام + ملاحظات الأيام", "Work summary + Day notes"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.forward")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary.opacity(0.5))
                .flipsForRightToLeftLayoutDirection(true)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ShiftTheme.ColorToken.brandPrimary.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.05),
            radius: 10,
            y: 4
        )
    }

    // MARK: - Info Note

    private var infoNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary.opacity(0.6))

            Text(tr(
                "التقرير يتضمن إحصائيات الدوام وملاحظاتك المسجلة (إن وجدت).",
                "Report includes work stats and your logged notes (if any)."
            ))
            .font(.system(.caption, design: .rounded))
            .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
