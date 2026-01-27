import SwiftUI

/// ServicesHubView (renamed to Records Hub)
/// مركز السجلات — يتضمن كرت ملخص + 3 أقسام رئيسية.
struct ServicesHubView: View {

    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var settings = UserSettingsStore.shared
    @StateObject private var messagesStore = MessagesStore.shared
    @ObservedObject private var userShift = UserShift.shared
    @ObservedObject private var leaveStore = ManualLeaveStore.shared

    // Calculator for stats
    private let calculator = WorkDaysCalculator()

    // Computed stats for current month
    private var monthStats: WorkDaysCalculator.Result {
        guard let context = userShift.shiftContext else {
            return .init(workingDaysTotal: 0, leaveDaysEffective: 0, netWorkingDays: 0, netWorkingMinutes: 0)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: settings.language.rawValue)

        let now = Date()
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!

        return calculator.calculate(
            from: start,
            to: end,
            context: context,
            referenceDate: context.referenceDate
        )
    }

    private var attendancePercentage: Double {
        guard monthStats.workingDaysTotal > 0 else { return 0 }
        return Double(monthStats.netWorkingDays) / Double(monthStats.workingDaysTotal)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ShiftTheme.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        headerSection

                        // كرت ملخص الشهر
                        monthlySummaryCard
                            .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)

                        // الأقسام الرئيسية
                        VStack(spacing: 16) {

                            // 1. 📋 سجلاتي (الاستئذانات + التقارير)
                            NavigationLink {
                                MyRecordsView()
                            } label: {
                                WideServiceCard(
                                    title: tr("سجلاتي", "My Records"),
                                    subtitle: tr("الاستئذانات، الخصومات، والتقارير", "Permissions, deductions, & reports"),
                                    systemImage: "doc.text.fill",
                                    tint: ShiftTheme.ColorToken.brandPrimary
                                )
                            }
                            .buttonStyle(.plain)

                            // 2. 🔔 إعداد التنبيهات
                            NavigationLink {
                                NotificationsSettingsView(settings: settings)
                            } label: {
                                WideServiceCard(
                                    title: tr("إعداد التنبيهات", "Alerts Setup"),
                                    subtitle: tr("تخصيص مواقيت التذكيرات", "Customize reminder times"),
                                    systemImage: "bell.badge.circle.fill",
                                    tint: ShiftTheme.ColorToken.brandWarning
                                )
                            }
                            .buttonStyle(.plain)

                            // 3. 📊 سجل النشاط (مدمج من تبويب سابق)
                            NavigationLink {
                                UpdatesView()
                            } label: {
                                WideServiceCard(
                                    title: tr("سجل النشاط", "Activity Log"),
                                    subtitle: tr("تاريخ جميع الإجراءات المسجلة", "History of all recorded actions"),
                                    systemImage: "clock.arrow.circlepath",
                                    tint: .purple,
                                    badgeCount: messagesStore.unreadCount
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)

                        // قسم النشاط الأخير (معاينة سريعة)
                        recentActivitySection

                        Spacer(minLength: 100)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle(tr("السجلات", "Records"))
            .navigationBarTitleDisplayMode(.large)
        }
        .environment(\.layoutDirection, settings.language.direction)
    }

    // MARK: - Monthly Summary Card
    private var monthlySummaryCard: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Text(tr("ملخص الشهر", "Monthly Summary"))
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)

                Spacer()

                Text(currentMonthName)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            // Stats Row
            HStack(spacing: 12) {
                // Attendance Percentage
                SummaryStatItem(
                    value: "\(Int(attendancePercentage * 100))%",
                    label: tr("الالتزام", "Attendance"),
                    color: ShiftTheme.ColorToken.brandPrimary
                )

                // Deductions
                SummaryStatItem(
                    value: "\(monthStats.leaveDaysEffective)",
                    label: tr("أيام خصم", "Deductions"),
                    color: monthStats.leaveDaysEffective > 0 ? .red : .secondary
                )

                // Net Days
                SummaryStatItem(
                    value: "\(monthStats.netWorkingDays)",
                    label: tr("صافي الأيام", "Net Days"),
                    color: .green
                )
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ShiftTheme.ColorToken.brandPrimary.opacity(0.15), lineWidth: 1)
        )
    }

    private var currentMonthName: String {
        let formatter = DateFormatter()
        // Phase 2: Use Latin digits locale for consistent number display
        formatter.locale = settings.language == .arabic
            ? Locale(identifier: "ar_SA@numbers=latn")
            : Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date())
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.14 : 0.10))
                    .frame(width: 70, height: 70)

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 28))
                    .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
            }

            VStack(spacing: 4) {
                Text(tr("مركز السجلات", "Records Hub"))
                    .font(.system(size: 22, weight: .black, design: .rounded))

                Text(tr("سجلاتك وتنبيهاتك وتاريخ النشاط", "Your records, alerts & activity history"))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 10)
    }

    // MARK: - Recent Activity Section
    @ViewBuilder
    private var recentActivitySection: some View {
        let recentMessages = Array(messagesStore.messages.prefix(3))

        if !recentMessages.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(tr("النشاط الأخير", "Recent Activity"))
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)

                    Spacer()

                    NavigationLink {
                        UpdatesView()
                    } label: {
                        Text(tr("عرض الكل", "View All"))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                    }
                }

                VStack(spacing: 8) {
                    ForEach(recentMessages) { message in
                        RecentActivityRow(message: message)
                    }
                }
            }
            .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
        }
    }
}

// MARK: - Recent Activity Row (للعرض المصغر)
private struct RecentActivityRow: View {
    let message: SystemMessage
    @Environment(\.colorScheme) private var colorScheme

    private var sourceIcon: String {
        switch message.sourceType {
        case .manualLeave: return "suitcase.fill"
        case .shiftEvent: return "clock.badge.checkmark"
        case .shift: return "calendar.badge.exclamationmark"
        case .system: return "bell.fill"
        case .attendance: return "checkmark.circle.fill"
        case .notification: return "bell.badge.fill"  // Phase 3: Notification events
        case .validation: return "exclamationmark.shield.fill"  // Phase 4: Validation events
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Unread indicator
            Circle()
                .fill(message.isRead ? Color.clear : ShiftTheme.ColorToken.brandPrimary)
                .frame(width: 6, height: 6)

            // Icon
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(colorScheme == .dark ? 0.15 : 0.10))
                    .frame(width: 32, height: 32)

                Image(systemName: sourceIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.purple)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(message.title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(message.isRead ? .medium : .bold)
                    .lineLimit(1)

                Text(message.body)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Relative time
            Text(message.date.relativeShort)
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Date Extension for Relative Time
private extension Date {
    var relativeShort: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Wide Service Card (للتصميم المبسط)
private struct WideServiceCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var badgeCount: Int = 0

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 16) {
            // الأيقونة مع شارة اختيارية
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(colorScheme == .dark ? 0.2 : 0.15))
                        .frame(width: 52, height: 52)

                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(tint)
                }

                // Badge for unread count
                if badgeCount > 0 {
                    Text("\(min(badgeCount, 99))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(5)
                        .background(Circle().fill(ShiftTheme.ColorToken.brandDanger))
                        .offset(x: 6, y: -4)
                }
            }

            // النصوص
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)

                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            // سهم التنقل
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.secondary.opacity(0.4))
                .flipsForRightToLeftLayoutDirection(true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.08 : 0.03), radius: 6, y: 3)
    }
}

// MARK: - My Records View (يجمع الاستئذانات + التقارير)
struct MyRecordsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var settings = UserSettingsStore.shared

    var body: some View {
        ZStack {
            ShiftTheme.appBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    // 1. الاستئذانات الساعية
                    NavigationLink {
                        HourlyPermissionsLogView()
                    } label: {
                        RecordRow(
                            title: tr("الاستئذانات", "Permissions"),
                            subtitle: tr("التأخير، الخروج المبكر، والعمل الإضافي", "Delays, early exits, & overtime"),
                            icon: "clock.badge.exclamationmark.fill",
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)

                    // 2. التقارير
                    NavigationLink {
                        ReportsHomeView()
                    } label: {
                        RecordRow(
                            title: tr("التقارير", "Reports"),
                            subtitle: tr("تصدير كشوفات الدوام", "Export shift summaries"),
                            icon: "doc.text.fill",
                            tint: ShiftTheme.ColorToken.brandPrimary
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                .padding(.top, 20)
            }
        }
        .navigationTitle(tr("سجلاتي", "My Records"))
        .navigationBarTitleDisplayMode(.large)
        .environment(\.layoutDirection, settings.language.direction)
    }
}

// MARK: - Record Row (لعرض عناصر سجلاتي)
private struct RecordRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(tint.opacity(colorScheme == .dark ? 0.15 : 0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)

                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary.opacity(0.4))
                .flipsForRightToLeftLayoutDirection(true)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// MARK: - Summary Stat Item
private struct SummaryStatItem: View {
    let value: String
    let label: String
    let color: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.system(.caption2, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(colorScheme == .dark ? 0.10 : 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
