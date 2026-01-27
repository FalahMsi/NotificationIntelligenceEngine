import SwiftUI
import Combine

/// CalendarView
/// الواجهة الرئيسية لعرض التقويم.
struct CalendarView: View {
    
    // MARK: - Dependencies
    @ObservedObject private var settings: UserSettingsStore
    @StateObject private var viewModel: CalendarViewModel
    
    // مراقبة المصادر الخارجية
    @ObservedObject private var leaveStore = ManualLeaveStore.shared
    @ObservedObject private var calendarService = SystemCalendarService.shared
    @ObservedObject private var userShift = UserShift.shared
    @ObservedObject private var achievementStore = AchievementStore.shared
    @ObservedObject private var eventStore = ShiftEventStore.shared
    
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - State
    @State private var selectedDay: ShiftDay?
    @State private var years: [Int] = []
    @State private var pagerYear: Int = 0
    @State private var showShiftEditor = false
    @State private var showYearPicker = false
    @State private var scrollToTodayTrigger = UUID() // Trigger for scrolling to today
    
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: settings.language.rawValue)
        cal.timeZone = .current
        return cal
    }
    
    // MARK: - Init
    init(settings: UserSettingsStore) {
        self._settings = ObservedObject(wrappedValue: settings)
        _viewModel = StateObject(wrappedValue: CalendarViewModel(settings: settings))
    }
    
    // MARK: - Today Context

    private var todayDay: ShiftDay? {
        let today = calendar.startOfDay(for: Date())
        guard let monthDate = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) else { return nil }

        return viewModel.days(in: monthDate).first {
            !($0.date == Date.distantPast) &&
            calendar.isDate($0.date, inSameDayAs: today)
        }
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {

            // 1. Today Hero Card — الكرت الرئيسي للإجابة السريعة
            VStack(spacing: 10) {
                // شارة اختيار النظام (مصغرة)
                HStack {
                    SelectedShiftBadge {
                        showShiftEditor = true
                    }
                    .sheet(isPresented: $showShiftEditor) {
                        ShiftSelectionSheet()
                    }
                    Spacer()
                }

                // الكرت الرئيسي: حالة الدوام + العد التنازلي + نسبة الالتزام
                TodayHeroCard(
                    todayDay: todayDay,
                    hasLeave: todayDay.map { leaveStore.hasLeave(on: $0.date) } ?? false,
                    settings: settings
                )
            }
            .padding(.horizontal, ShiftTheme.Spacing.md)
            .padding(.top, ShiftTheme.Spacing.sm)
            .padding(.bottom, ShiftTheme.Spacing.md)
            
            // 2. ترويسة التقويم (مصغرة لإعطاء الأولوية للكرت الرئيسي)
            VStack(spacing: 8) {
                HStack {
                    // زر اختيار السنة (بديل عن السحب المربك)
                    Button {
                        showYearPicker = true
                        HapticManager.shared.impact(.light)
                    } label: {
                        HStack(spacing: 6) {
                            Text(yearString(pagerYear))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // زر العودة لليوم الحالي — يعمل دائماً
                    Button {
                        let currentYear = Calendar.current.component(.year, from: Date())
                        if pagerYear != currentYear {
                            withAnimation(.spring(response: 0.3)) {
                                pagerYear = currentYear
                            }
                        }
                        // Trigger scroll to current month
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scrollToTodayTrigger = UUID()
                        }
                        HapticManager.shared.impact(.light)
                    } label: {
                        Text(tr("اليوم", "Today"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.15 : 0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, ShiftTheme.Spacing.lg)

                weekDaysHeader
                    .padding(.horizontal, ShiftTheme.Spacing.md + 4)
            }
            .padding(.bottom, 6)
            .sheet(isPresented: $showYearPicker) {
                YearPickerSheet(selectedYear: $pagerYear, years: years)
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
            }
            
            // 3. التقويم التمريري
            yearPager
        }
        .background(Color.clear)
        .sheet(item: $selectedDay) { day in
            DayDetailsSheet(day: day)
        }
        .environment(\.layoutDirection, settings.language.direction)
        .onAppear {
            if years.isEmpty { setupYears() }
            pagerYear = viewModel.currentYear
            viewModel.forceRefresh()
            refreshSystemEvents()
        }
        .onReceive(NotificationCenter.default.publisher(for: .scrollCalendarToToday)) { _ in
            // Scroll to today when calendar tab is re-tapped
            let currentYear = Calendar.current.component(.year, from: Date())
            if pagerYear != currentYear {
                withAnimation(.spring(response: 0.3)) {
                    pagerYear = currentYear
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scrollToTodayTrigger = UUID()
            }
            HapticManager.shared.impact(.light)
        }
    }
    
    // MARK: - Logic & Refreshes
    private func refreshSystemEvents() {
        let now = Date()
        if let start = calendar.date(byAdding: .year, value: -1, to: now),
           let end = calendar.date(byAdding: .year, value: 1, to: now) {
            calendarService.fetchEvents(from: start, to: end)
        }
    }
    
    // MARK: - Component Views
    private var weekDaysHeader: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)
        let symbols = viewModel.weekDaySymbols()
        
        return LazyVGrid(columns: columns) {
            ForEach(0..<symbols.count, id: \.self) { index in
                Text(symbols[index])
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    /// عرض السنة المحددة (بدون سحب بين السنوات — الاختيار من القائمة أوضح)
    private var yearPager: some View {
        yearView(for: pagerYear)
            .id(pagerYear) // إعادة البناء عند تغيير السنة
    }

    private func yearView(for year: Int) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 30) {
                    ForEach(months(in: year), id: \.self) { monthDate in
                        monthBlock(for: monthDate)
                            .id(monthID(for: monthDate))
                    }
                    Spacer().frame(height: 100)
                }
                .padding(.top, 4)
                .padding(.horizontal, ShiftTheme.Spacing.md)
            }
            .onChange(of: scrollToTodayTrigger) { _, _ in
                scrollToCurrentMonth(proxy: proxy)
            }
            .onAppear {
                // Auto-scroll to current month on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToCurrentMonth(proxy: proxy)
                }
            }
        }
    }

    /// Generates a zero-padded month ID for ScrollView identification.
    /// Format: YYYY-MM (e.g., "2026-01" not "2026-1")
    /// Consistent with DayKeyGenerator formatting convention.
    private func monthID(for monthDate: Date) -> String {
        let comps = calendar.dateComponents([.year, .month], from: monthDate)
        return String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
    }

    private func scrollToCurrentMonth(proxy: ScrollViewProxy) {
        let now = Date()
        let comps = calendar.dateComponents([.year, .month], from: now)
        let id = String(format: "%04d-%02d", comps.year ?? 0, comps.month ?? 0)
        withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(id, anchor: .top)
        }
    }
    
    private func monthBlock(for monthDate: Date) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // ✅ Phase 4: Month header with subtle top divider
            VStack(spacing: 8) {
                // Month divider (except for first month of year)
                if calendar.component(.month, from: monthDate) != 1 {
                    Rectangle()
                        .fill(ShiftTheme.CalendarColors.monthDivider)
                        .frame(height: 1)
                        .padding(.horizontal, 4)
                }

                Text(viewModel.monthTitle(for: monthDate))
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                    .padding(.horizontal, 4)
            }

            // Calendar grid (restored original working approach)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

            LazyVGrid(columns: columns, spacing: 15) {
                ForEach(0..<viewModel.paddingDays(for: monthDate), id: \.self) { _ in
                    Color.clear.frame(height: 40)
                }

                ForEach(viewModel.days(in: monthDate)) { day in
                    let isToday = viewModel.isToday(day.date)
                    let dayDate = calendar.startOfDay(for: day.date)

                    let hasLeave = leaveStore.hasLeave(on: dayDate)
                    let hasOverride = userShift.manualOverride(for: dayDate) != nil
                    let hasSystemEvent = !(calendarService.eventsByDay[dayDate]?.isEmpty ?? true)
                    let hasAchievement = achievementStore.achievements.contains {
                        calendar.isDate($0.date, inSameDayAs: dayDate)
                    }

                    Button {
                        HapticManager.shared.impact(.light)
                        selectedDay = day
                    } label: {
                        DayCellView(
                            day: day,
                            isToday: isToday,
                            hasManualLeave: hasLeave,
                            hasManualOverride: hasOverride,
                            hasAchievement: hasAchievement,
                            hasSystemEvent: hasSystemEvent
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Date Helpers
    private func setupYears() {
        let current = Calendar.current.component(.year, from: Date())
        years = Array((current - 2)...(current + 2))
    }
    
    private func months(in year: Int) -> [Date] {
        (1...12).compactMap {
            calendar.date(from: DateComponents(year: year, month: $0, day: 1))
        }
    }
    
    private func yearString(_ year: Int) -> String {
        return String(year)  // Phase 2: Direct conversion bypasses locale grouping (no "2,026")
    }
}

// MARK: - Today Hero Card

/// الكرت الرئيسي الذي يظهر حالة الدوام اليوم مع العد التنازلي الحي.
/// يجيب على السؤال الأهم: "ما هو دوامي اليوم، وهل أنا على المسار؟"
private struct TodayHeroCard: View {

    // MARK: - Input
    let todayDay: ShiftDay?
    let hasLeave: Bool

    // MARK: - Dependencies
    @ObservedObject private var userShift = UserShift.shared
    @ObservedObject var settings: UserSettingsStore

    // MARK: - State
    @State private var now = Date()
    @State private var commitmentPercentage: Double = 0

    // MARK: - Environment
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Private
    private let calculator = WorkDaysCalculator()
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // MARK: - Timing State
    private enum ShiftTimingState {
        case completed
        case inProgress(remaining: TimeInterval)
        case upcoming(countdown: TimeInterval)
        case scheduled
        case dayOff
        case leave
        case unknown
    }

    private var currentTimingState: ShiftTimingState {
        guard let day = todayDay else { return .unknown }

        if hasLeave { return .leave }

        guard day.shiftPhase.isCountedAsWorkDay else { return .dayOff }

        guard let times = calculateShiftTimes() else { return .scheduled }

        if now > times.end { return .completed }
        if now < times.start {
            let diff = times.start.timeIntervalSince(now)
            return diff < (24 * 3600) ? .upcoming(countdown: diff) : .scheduled
        }
        return .inProgress(remaining: times.end.timeIntervalSince(now))
    }

    // MARK: - Body
    var body: some View {
        HStack(spacing: 16) {
            // الأيقونة
            phaseIcon

            // المحتوى الرئيسي
            VStack(alignment: .leading, spacing: 6) {
                // العنوان الرئيسي (الحالة)
                Text(mainStatusText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                // التفاصيل الثانوية
                if let secondary = secondaryText {
                    Text(secondary)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .environment(\.layoutDirection, .leftToRight)
                }
            }

            Spacer()

            // شارة الالتزام (إذا كان يوم عمل)
            if shouldShowCommitmentBadge {
                commitmentBadge
            }
        }
        .padding(18)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(borderColor.opacity(0.2), lineWidth: 0.5)
        )
        .floatingShadow()
        .onReceive(timer) { _ in
            now = Date()
        }
        .onAppear {
            calculateCommitment()
        }
    }

    // MARK: - Subviews

    private var phaseIcon: some View {
        ZStack {
            Circle()
                .fill(phaseColor.opacity(colorScheme == .dark ? 0.2 : 0.15))
                .frame(width: 56, height: 56)

            Image(systemName: phaseIconName)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(phaseColor)
        }
    }

    private var cardBackground: some View {
        ZStack {
            Color.clear.background(.ultraThinMaterial)
            phaseColor.opacity(colorScheme == .dark ? 0.08 : 0.04)
        }
    }

    private var commitmentBadge: some View {
        NavigationLink(destination: WorkDashboardView()) {
            Text("\(Int(commitmentPercentage * 100))%")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.15 : 0.1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Computed Properties

    private var mainStatusText: String {
        switch currentTimingState {
        case .completed:
            return tr("الدوام انتهى ✅", "Shift Completed ✅")
        case .upcoming(let diff):
            return formatCountdown(diff, prefix: tr("يبدأ خلال", "Starts in"))
        case .inProgress(let diff):
            return formatCountdown(diff, prefix: tr("متبقي", "Remaining"))
        case .scheduled:
            return formattedTimeRange
        case .dayOff:
            return tr("يوم راحة 🌙", "Day Off 🌙")
        case .leave:
            return tr("إجازة مسجلة 📋", "On Leave 📋")
        case .unknown:
            return tr("لا توجد بيانات", "No data")
        }
    }

    private var secondaryText: String? {
        switch currentTimingState {
        case .upcoming, .inProgress:
            return formattedTimeRange
        case .scheduled, .dayOff, .leave, .completed, .unknown:
            return todayDay?.shiftPhase.displayName
        }
    }

    private var statusColor: Color {
        switch currentTimingState {
        case .completed: return .secondary
        case .inProgress: return .orange
        case .upcoming: return ShiftTheme.ColorToken.brandPrimary
        case .scheduled: return .primary
        case .dayOff: return ShiftTheme.ColorToken.brandRelief
        case .leave: return ShiftTheme.ColorToken.brandDanger
        case .unknown: return .secondary
        }
    }

    private var phaseColor: Color {
        guard let day = todayDay else { return .secondary }
        if hasLeave { return ShiftTheme.ColorToken.brandDanger }
        return ShiftTheme.phaseIndicatorColor(day.shiftPhase)
    }

    private var borderColor: Color {
        phaseColor
    }

    private var phaseIconName: String {
        switch currentTimingState {
        case .dayOff: return "moon.zzz.fill"
        case .leave: return "suitcase.fill"
        case .completed: return "checkmark.circle.fill"
        case .inProgress: return "clock.fill"
        case .upcoming: return "clock.badge.fill"
        default:
            return todayDay?.shiftPhase.iconName ?? "calendar"
        }
    }

    private var shouldShowCommitmentBadge: Bool {
        guard let day = todayDay else { return false }
        return day.shiftPhase.isCountedAsWorkDay && !hasLeave
    }

    // MARK: - Calculations

    private func calculateShiftTimes() -> (start: Date, end: Date)? {
        guard let day = todayDay,
              let context = userShift.shiftContext else { return nil }
        return ShiftEngine.shared.calculateExactShiftTimes(
            context: context,
            for: day.date,
            phase: day.shiftPhase
        )
    }

    private var formattedTimeRange: String {
        // Phase 4: Use shared ShiftTimeFormatter for consistency (supports +1, +2, etc.)
        guard let day = todayDay,
              let context = userShift.shiftContext else {
            return todayDay?.shiftPhase.displayName ?? ""
        }
        return ShiftEngine.formattedTimeRange(context: context, for: day.date, phase: day.shiftPhase)
            ?? todayDay?.shiftPhase.displayName ?? ""
    }

    private func formatCountdown(_ seconds: TimeInterval, prefix: String) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let hStr = tr("س", "h")
        let mStr = tr("د", "m")
        return "\(prefix) \(h)\(hStr) \(m)\(mStr)"
    }

    private func calculateCommitment() {
        guard let context = userShift.shiftContext else {
            commitmentPercentage = 0
            return
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: settings.language.rawValue)

        // حساب الشهر الحالي
        let now = Date()
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!

        let result = calculator.calculate(
            from: start,
            to: end,
            context: context,
            referenceDate: context.referenceDate
        )

        if result.workingDaysTotal > 0 {
            commitmentPercentage = Double(result.netWorkingDays) / Double(result.workingDaysTotal)
        } else {
            commitmentPercentage = 0
        }
    }
}

// MARK: - Year Picker Sheet

/// قائمة اختيار السنة — بديل واضح عن السحب المربك بين السنوات
private struct YearPickerSheet: View {
    @Binding var selectedYear: Int
    let years: [Int]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var body: some View {
        VStack(spacing: 16) {
            // العنوان
            Text(tr("اختر السنة", "Select Year"))
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .padding(.top, 8)

            // شبكة السنوات
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(years, id: \.self) { year in
                    Button {
                        selectedYear = year
                        HapticManager.shared.impact(.medium)
                        dismiss()
                    } label: {
                        Text(String(year))  // Phase 2: Direct conversion bypasses locale grouping
                            .font(.system(size: 18, weight: year == selectedYear ? .black : .semibold, design: .rounded))
                            .foregroundColor(yearTextColor(year))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(yearBackground(year))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(yearBorderColor(year), lineWidth: year == selectedYear ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding(.top, 12)
    }

    private func yearTextColor(_ year: Int) -> Color {
        if year == selectedYear {
            return ShiftTheme.ColorToken.brandPrimary
        } else if year == currentYear {
            return .primary
        } else {
            return .secondary
        }
    }

    private func yearBackground(_ year: Int) -> Color {
        if year == selectedYear {
            return ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.15 : 0.1)
        } else {
            return Color.primary.opacity(0.05)
        }
    }

    private func yearBorderColor(_ year: Int) -> Color {
        year == selectedYear ? ShiftTheme.ColorToken.brandPrimary : .clear
    }
}
