import Foundation
import Combine

/// UnifiedReportService
/// مسؤول عن تجميع وإعداد كافة بيانات التقرير الموحد (الدوام + الإجازات + الإنجازات).
struct UnifiedReportService {

    // MARK: - Dependencies
    private let workCalculator = WorkDaysCalculator()
    private let leaveStore = ManualLeaveStore.shared
    private let achievementStore = AchievementStore.shared
    private let eventStore = ShiftEventStore.shared

    // MARK: - Public API

    /// توليد نموذج بيانات شامل للتقرير بين تاريخين محددين
    @MainActor
    func generateReport(
        from startDate: Date,
        to endDate: Date,
        context: ShiftContext
    ) -> UnifiedReport {

        let language = UserSettingsStore.shared.language
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: language.rawValue)
        calendar.timeZone = .current

        // 1️⃣ حساب إحصائيات الدوام الفعلي (صافي الدقائق والساعات)
        let workStats = workCalculator.calculate(
            from: startDate,
            to: endDate,
            context: context,
            referenceDate: context.referenceDate
        )

        // 2️⃣ تحليل وتفصيل أنواع الإجازات (أيام كاملة)
        let leaveBreakdown = calculateLeaveBreakdown(
            from: startDate,
            to: endDate,
            calendar: calendar
        )
        
        // 3️⃣ تحليل وتفصيل الأحداث الساعية (تأخيرات، استئذانات، إضافي)
        let eventBreakdown = calculateEventBreakdown(from: startDate, to: endDate, language: language)

        // 4️⃣ إنشاء نموذج تقرير أيام العمل (بالبيانات الدقيقة)
        let workReport = WorkDaysReport(
            fromDate: startDate,
            toDate: endDate,
            workingDaysTotal: workStats.workingDaysTotal,
            leaveDaysEffective: workStats.leaveDaysEffective,
            netWorkingDays: workStats.netWorkingDays,
            netWorkingHours: workStats.netWorkingHours,
            leaveBreakdown: leaveBreakdown,
            eventBreakdown: eventBreakdown,
            generatedAt: Date()
        )

        // 5️⃣ تجميع سجل الإنجازات ضمن الفترة المحددة
        let startBound = calendar.startOfDay(for: startDate)
        let endBound = calendar.startOfDay(for: endDate)

        let achievements = achievementStore.achievements.filter {
            let achievementDate = calendar.startOfDay(for: $0.date)
            return achievementDate >= startBound && achievementDate <= endBound
        }
        .sorted { $0.date < $1.date }

        // 6️⃣ الكيان النهائي للتقرير الموحد
        return UnifiedReport(
            periodStart: startDate,
            periodEnd: endDate,
            workReport: workReport,
            achievements: achievements
        )
    }

    // MARK: - Internal Analytical Helpers

    private func calculateLeaveBreakdown(from start: Date, to end: Date, calendar: Calendar) -> [LeaveBreakdownItem] {
        var counts: [ManualLeaveType: Int] = [:]
        var current = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)

        while current <= endDay {
            if let leave = leaveStore.getLeave(on: current) {
                counts[leave.type, default: 0] += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        return counts.map { LeaveBreakdownItem(title: $0.key.localizedName, days: $0.value, color: $0.key.color) }
                     .sorted { $0.days > $1.days }
    }
    
    @MainActor
    private func calculateEventBreakdown(from start: Date, to end: Date, language: AppLanguage) -> [EventBreakdownItem] {
        let events = eventStore.events.filter { $0.date >= start && $0.date <= end }
        
        var typeTotals: [ShiftEventType: Int] = [:]
        for event in events {
            typeTotals[event.type, default: 0] += event.durationMinutes
        }
        
        return typeTotals.map { (type, minutes) in
            EventBreakdownItem(
                title: type.localizedName(language: language),
                totalMinutes: minutes,
                icon: type.iconName,
                color: type.defaultImpact.color
            )
        }.sorted { $0.totalMinutes > $1.totalMinutes }
    }
}
