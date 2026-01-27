import SwiftUI
import Combine

/// WorkDashboardView (Simplified)
/// واجهة مبسطة للإحصائيات: كرت واحد يعرض نسبة الالتزام والأرقام الأساسية فقط.
/// يتم عرضه كـ Sheet من شارة الالتزام على الشاشة الرئيسية.
struct WorkDashboardView: View {

    // MARK: - Dependencies
    @EnvironmentObject private var settings: UserSettingsStore
    @ObservedObject private var leaveStore = ManualLeaveStore.shared
    @StateObject private var viewModel = WorkDashboardViewModel()

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            // Main content
            VStack(spacing: 24) {
                headerSection
                progressRing
                statsRow
                infoNote
            }
            .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)

            Spacer()
        }
        .background(ShiftTheme.appBackground.ignoresSafeArea())
        .onAppear { triggerRefresh() }
        .onReceive(
            leaveStore.objectWillChange
                .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
        ) { _ in
            triggerRefresh()
        }
        .environment(\.layoutDirection, settings.language.direction)
    }

    private func triggerRefresh() {
        let context = UserShift.shared.shiftContext
        viewModel.recalculate(context: context, language: settings.language)
    }
}

// MARK: - Sections

private extension WorkDashboardView {

    var headerSection: some View {
        VStack(spacing: 8) {
            Text(tr("إحصائيات الشهر", "Monthly Stats"))
                .font(.system(size: 22, weight: .black, design: .rounded))

            Text(viewModel.periodScopeLabel(isArabic: settings.language == .arabic))
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    var progressRing: some View {
        ZStack {
            Circle()
                .stroke(
                    colorScheme == .dark
                    ? Color.white.opacity(0.05)
                    : Color.black.opacity(0.05),
                    lineWidth: 20
                )
                .frame(width: 160, height: 160)

            Circle()
                .trim(from: 0, to: viewModel.attendancePercentage)
                .stroke(
                    LinearGradient(
                        colors: [
                            ShiftTheme.ColorToken.brandPrimary,
                            ShiftTheme.ColorToken.brandInfo
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 160, height: 160)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.attendancePercentage)

            VStack(spacing: 0) {
                Text("\(Int(viewModel.attendancePercentage * 100))%")
                    .font(.system(size: 40, weight: .black, design: .rounded))

                Text(tr("الالتزام", "Commitment"))
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 10)
    }

    var statsRow: some View {
        HStack(spacing: 16) {
            StatMiniCard(
                title: tr("مجدول", "Scheduled"),
                value: "\(viewModel.stats.workingDaysTotal)",
                color: .blue
            )

            StatMiniCard(
                title: tr("خصومات", "Deductions"),
                value: "\(viewModel.stats.leaveDaysEffective)",
                color: viewModel.stats.leaveDaysEffective > 0 ? .red : .secondary
            )

            StatMiniCard(
                title: tr("صافي", "Net"),
                value: "\(viewModel.stats.netWorkingDays)",
                color: .green,
                isHighlight: true
            )
        }
    }

    var infoNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundColor(.secondary.opacity(0.6))

            Text(tr(
                "الأرقام مبنية على سجلاتك اليدوية.",
                "Based on your manual records."
            ))
            .font(.system(.caption, design: .rounded))
            .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }
}

// MARK: - Stat Mini Card

private struct StatMiniCard: View {
    let title: String
    let value: String
    let color: Color
    var isHighlight: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(isHighlight ? color : .primary)

            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(colorScheme == .dark ? 0.10 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isHighlight ? color.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - ViewModel

@MainActor
final class WorkDashboardViewModel: ObservableObject {

    @Published var stats: WorkDaysCalculator.Result = .init(
        workingDaysTotal: 0,
        leaveDaysEffective: 0,
        netWorkingDays: 0,
        netWorkingMinutes: 0
    )

    private let calculator = WorkDaysCalculator()

    var attendancePercentage: Double {
        guard stats.workingDaysTotal > 0 else { return 0 }
        return Double(stats.netWorkingDays) / Double(stats.workingDaysTotal)
    }

    func periodScopeLabel(isArabic: Bool) -> String {
        let now = Date()
        let f = DateFormatter()
        // Phase 2: Use Latin digits locale for consistent number display
        f.locale = isArabic ? Locale(identifier: "ar_SA@numbers=latn") : Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: now)
    }

    func recalculate(context: ShiftContext?, language: AppLanguage) {
        let activeContext = context ?? UserShift.shared.shiftContext

        guard let finalContext = activeContext else {
            stats = .init(workingDaysTotal: 0, leaveDaysEffective: 0, netWorkingDays: 0, netWorkingMinutes: 0)
            return
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: language.rawValue)

        // Always current month only (simplified)
        let now = Date()
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!

        self.stats = calculator.calculate(
            from: start,
            to: end,
            context: finalContext,
            referenceDate: finalContext.referenceDate
        )
    }
}

// MARK: - DashboardStatCard (Legacy - kept for compatibility)

struct DashboardStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    var isHighlight: Bool = false
    let language: AppLanguage

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: language == .arabic ? .trailing : .leading, spacing: 14) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(colorScheme == .dark ? 0.15 : 0.12))
                        .frame(width: 38, height: 38)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(color)
                }

                if language == .english { Spacer() }

                if isHighlight {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .shadow(color: color.opacity(0.5), radius: 4)
                }

                if language == .arabic { Spacer() }
            }

            VStack(alignment: language == .arabic ? .trailing : .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.7)

                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isHighlight ? color.opacity(0.4) : Color.primary.opacity(0.08), lineWidth: 1.5)
        )
    }
}

// MARK: - DashboardPeriod (Legacy - kept for compatibility)

enum DashboardPeriod: String, CaseIterable {
    case currentMonth
    case currentYear

    func dateRange(for calendar: Calendar) -> (start: Date, end: Date) {
        let now = Date()
        switch self {
        case .currentMonth:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return (start, end)
        case .currentYear:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let end = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: start)!
            return (start, end)
        }
    }
}
