import Foundation
import SwiftUI
import Combine

@MainActor
final class CalendarViewModel: ObservableObject {

    // MARK: - Dependencies
    let settings: UserSettingsStore
    let calendarService = SystemCalendarService.shared
    private let userShift = UserShift.shared

    // MARK: - Dynamic Calendar Provider
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: settings.language.rawValue)
        cal.firstWeekday = settings.language == .arabic ? 7 : 1 // السبت للعربية، الأحد للإنجليزية
        return cal
    }

    // MARK: - State
    @Published var currentYear: Int
    @Published private(set) var refreshID = UUID()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(settings: UserSettingsStore) {
        self.settings = settings
        self.currentYear = Calendar.current.component(.year, from: Date())
        bindChanges()
    }

    // MARK: - Bindings
    private func bindChanges() {
        // تحديث عند تغيير الإعدادات (اللغة، النظام)
        settings.objectWillChange
            .sink { [weak self] in self?.forceRefresh() }
            .store(in: &cancellables)

        // تحديث عند تغيير بيانات النوبات (تعديل يدوي، تبديل)
        userShift.objectWillChange
            .sink { [weak self] in self?.forceRefresh() }
            .store(in: &cancellables)
            
        // تحديث عند منتصف الليل (لتغيير "اليوم")
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .sink { [weak self] _ in self?.forceRefresh() }
            .store(in: &cancellables)
    }

    func forceRefresh() {
        refreshID = UUID()
    }

    // MARK: - Weekdays Headers
    func weekDaySymbols() -> [String] {
        settings.language == .arabic
        ? ["س", "ح", "ن", "ث", "ر", "خ", "ج"]
        : ["S", "M", "T", "W", "T", "F", "S"]
    }

    // MARK: - Days Builder (The Engine Link)
    func days(in monthDate: Date) -> [ShiftDay] {
        _ = refreshID // Trigger refresh

        guard
            settings.isSetupComplete,
            let context = userShift.shiftContext,
            let monthInterval = calendar.dateInterval(of: .month, for: monthDate)
        else { return [] }

        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end
        let range = calendar.range(of: .day, in: .month, for: monthStart)!
        let daysCount = range.count

        // 1. توليد الخط الزمني الأساسي من المحرك
        let timeline = ShiftEngine.shared.generateTimeline(
            systemID: context.systemID,
            context: context,
            from: monthStart,
            days: daysCount
        )

        // 2. تطبيق التعديلات اليدوية والعطلات
        return timeline.items
            .filter { $0.date >= monthStart && $0.date < monthEnd }
            .map { item in
                let dayDate = calendar.startOfDay(for: item.date)
                
                // أ. التحقق من التعديل اليدوي (Manual Override)
                let manualOverride = userShift.manualOverride(for: dayDate)
                var finalPhase = manualOverride ?? item.phase

                // ب. التحقق من العطلات الرسمية (فقط للأنظمة الصباحية/المكتبية)
                // الأنظمة التبادلية (شفتات) لا تتوقف في العطل عادةً إلا بتعديل يدوي
                if isOfficialHoliday(dayDate) {
                    let systemName = String(describing: context.systemID).lowercased()
                    if systemName.contains("standard") || systemName.contains("morning") || systemName.contains("eight") {
                        // إذا لم يكن هناك تعديل يدوي يفرض الدوام، اجعلها عطلة
                        if manualOverride == nil {
                            finalPhase = .weekend // نستخدم weekend كرمز للعطلة هنا
                        }
                    }
                }

                return ShiftDay(
                    date: dayDate,
                    shiftPhase: finalPhase,
                    calendarEvents: calendarService.eventsByDay[dayDate] ?? []
                )
            }
    }

    private func isOfficialHoliday(_ date: Date) -> Bool {
        // يمكن ربط هذا لاحقاً بقاعدة بيانات العطلات المحلية
        // حالياً نعتمد على التقويم (الجمعة/السبت) كعطلة افتراضية للأنظمة الصباحية
        // أو أي منطق مخصص في ShiftEngine
        return ShiftEngine.shared.isOfficialHoliday(date)
    }

    // MARK: - Grid Layout Helpers
    func paddingDays(for monthDate: Date) -> Int {
        let components = calendar.dateComponents([.year, .month], from: monthDate)
        guard let firstOfMonth = calendar.date(from: components) else { return 0 }
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        
        // حساب الإزاحة بناءً على بداية الأسبوع (السبت أو الأحد)
        return (firstWeekday - calendar.firstWeekday + 7) % 7
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    func monthTitle(for monthDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.language.rawValue)
        formatter.dateFormat = "MMMM"
        return formatter.string(from: monthDate)
    }
}
