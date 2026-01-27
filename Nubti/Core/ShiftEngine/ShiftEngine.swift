import Foundation

/// ShiftEngine
/// 🧠 العقل المركزي الوحيد لأنظمة النوبات.
/// تم التحديث: أصبح المسؤول الأول عن حساب التوقيت الدقيق بالربط بين (إعدادات المستخدم) و (قواعد النظام).
final class ShiftEngine {

    // MARK: - Singleton
    static let shared = ShiftEngine()
    private init() {}

    // MARK: - Registered Systems
    // يتم تحميل الأنظمة مرة واحدة فقط
    private let systems: [ShiftSystemID: ShiftSystemProtocol] = [
        .threeShiftTwoOff: ThreeShiftTwoOffSystem(),
        .twentyFourFortyEight: TwentyFourFortyEightSystem(),
        .twoWorkFourOff: TwoWorkFourOffSystem(),
        .standardMorning: StandardMorningSchedule(),
        .eightHourShift: EightHourShiftSystem()
    ]
    
    // MARK: - Centralized Holiday Logic 🇰🇼

    /// Check if a date is an official holiday using the HolidayProvider system.
    /// This delegates to HolidayProviderRegistry which supports:
    /// - Multi-year holidays (not hardcoded to a single year)
    /// - Regional customization (Kuwait, UAE, Saudi, etc.)
    /// - Both fixed and Islamic (Hijri) holidays
    ///
    /// - Parameter date: The date to check
    /// - Returns: true if the date is an official holiday
    ///
    /// - SeeAlso: HolidayProvider.swift
    func isOfficialHoliday(_ date: Date) -> Bool {
        HolidayProviderRegistry.shared.isHoliday(date)
    }

    /// Get the name of a holiday if the date is a holiday.
    /// - Parameter date: The date to check
    /// - Returns: Localized holiday name, or nil if not a holiday
    func holidayName(for date: Date) -> String? {
        HolidayProviderRegistry.shared.holidayName(for: date)
    }

    // MARK: - Public API

    func system(for id: ShiftSystemID) -> ShiftSystemProtocol {
        systems[id] ?? StandardMorningSchedule()
    }

    /// توليد الخط الزمني للنوبات
    func generateTimeline(
        systemID: ShiftSystemID,
        context: ShiftContext,
        from startDate: Date,
        days: Int
    ) -> ShiftTimeline {

        let system = system(for: systemID)
        
        return system.buildTimeline(
            context: context,
            from: startDate,
            days: days
        )
    }
    
    /// دالة سريعة لمعرفة هل اليوم عمل أم راحة
    func isWorkDay(_ date: Date, context: ShiftContext) -> Bool {
        let dayTimeline = generateTimeline(
            systemID: context.systemID,
            context: context,
            from: date,
            days: 1
        )
        return dayTimeline.items.first?.phase.isCountedAsWorkDay ?? false
    }
    
    // MARK: - ⏳ The Time Calculator (V3 - Cross-Midnight Fix)

    /// الدالة المركزية لحساب وقت البداية والنهاية لأي نوبة بدقة متناهية.
    /// تجمع بين (ساعة المستخدم) و (قواعد النظام) لتعطي وقتاً حياً.
    ///
    /// V3: يدعم النوبات الليلية التي تتخطى منتصف الليل (cross-midnight)
    ///
    /// - Parameters:
    ///   - context: إعدادات المستخدم (تحتوي على ساعة البدء المرجعية).
    ///   - date: تاريخ اليوم المراد حسابه.
    ///   - phase: النوبة (صباح، ليل، عصر...).
    /// - Returns: وقت البداية والنهاية كتواريخ (Date) فعلية.
    func calculateExactShiftTimes(
        context: ShiftContext,
        for date: Date,
        phase: ShiftPhase
    ) -> (start: Date, end: Date)? {

        // 1. التحقق من أن النوبة هي يوم عمل
        guard phase.isCountedAsWorkDay else { return nil }

        // 2. جلب النظام المسؤول
        let system = self.system(for: context.systemID)

        // 3. جلب "ساعة الصفر" من المستخدم (المرساة)
        let baseAnchorHour = context.baseStartHour

        // 4. سؤال النظام عن "قواعد الوقت" لهذه النوبة
        let offset = system.startOffset(for: phase) // مثلاً: +16 لليل

        // ✅ FIX: استخدام مدة المستخدم إن وجدت (Morning)، وإلا استخدام مدة النظام الافتراضية (Cyclic)
        let duration: Int
        if let userDuration = context.workDurationHours {
            duration = userDuration
        } else {
            duration = system.duration(for: phase)  // مثلاً: 8 ساعات للأنظمة الدورية
        }

        // 5. الحساب - استخدام التقويم مع المنطقة الزمنية
        var calendar = Calendar.current
        // V3: استخدام المنطقة الزمنية من السياق إذا كانت متاحة
        if let timeZone = context.timeZone {
            calendar.timeZone = timeZone
        }

        let startOfDay = calendar.startOfDay(for: date)

        // معادلة البداية: بداية اليوم + ساعة المستخدم + إزاحة النظام
        guard let start = calendar.date(byAdding: .hour, value: baseAnchorHour + offset, to: startOfDay),
              var end = calendar.date(byAdding: .hour, value: duration, to: start) else {
            return nil
        }

        // V3: معالجة النوبات الليلية (cross-midnight)
        // إذا كان وقت النهاية قبل أو يساوي وقت البداية، نضيف يوماً
        if end <= start {
            if let crossMidnightEnd = calendar.date(byAdding: .day, value: 1, to: end) {
                end = crossMidnightEnd
            }
        }

        return (start, end)
    }
}

// MARK: - Extension Helper
extension Calendar {
    func safeDateByAdding(hours: Int, minutes: Int, seconds: Int, to date: Date) -> Date {
        var components = DateComponents()
        components.hour = hours
        components.minute = minutes
        components.second = seconds
        return self.date(byAdding: components, to: date) ?? date
    }
}

// MARK: - Phase 4: Shared Time Range Formatting

extension ShiftEngine {

    /// DateFormatter configured for 24-hour time with Latin digits (per Phase 2 policy)
    private static var shiftTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }

    /// Formats shift time range with optional day offset indicator.
    /// Returns: "HH:mm - HH:mm" or "HH:mm - HH:mm (+N)" for cross-day shifts.
    ///
    /// Phase 4: Consolidates duplicated logic from 4 UI files into single source of truth:
    /// - SelectedShiftBadge.swift
    /// - TodayContextLine.swift
    /// - DayDetailsSheet.swift
    /// - CalendarView.swift
    ///
    /// - Parameters:
    ///   - context: The shift context containing user settings
    ///   - date: The date of the shift
    ///   - phase: The shift phase (morning, evening, night, etc.)
    /// - Returns: Formatted time range string, or nil if times cannot be calculated
    static func formattedTimeRange(
        context: ShiftContext,
        for date: Date,
        phase: ShiftPhase
    ) -> String? {
        // Get exact shift times from the engine (single source of truth)
        guard let times = shared.calculateExactShiftTimes(
            context: context,
            for: date,
            phase: phase
        ) else {
            return nil
        }

        let formatter = shiftTimeFormatter
        let startStr = formatter.string(from: times.start)
        let endStr = formatter.string(from: times.end)

        // Calculate day offset (supports +1, +2, etc. for future multi-day shifts)
        let calendar = Calendar.current
        let dayOffset = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: times.start),
            to: calendar.startOfDay(for: times.end)
        ).day ?? 0

        // Build offset indicator
        let offsetTag = dayOffset > 0 ? " (+\(dayOffset))" : ""

        return "\(startStr) - \(endStr)\(offsetTag)"
    }

    /// Checks if a shift crosses midnight (is an overnight shift).
    ///
    /// - Parameters:
    ///   - context: The shift context containing user settings
    ///   - date: The date of the shift
    ///   - phase: The shift phase (morning, evening, night, etc.)
    /// - Returns: true if shift ends on a different calendar day than it starts
    static func isOvernightShift(
        context: ShiftContext,
        for date: Date,
        phase: ShiftPhase
    ) -> Bool {
        guard let times = shared.calculateExactShiftTimes(
            context: context,
            for: date,
            phase: phase
        ) else {
            return false
        }

        let calendar = Calendar.current
        let dayOffset = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: times.start),
            to: calendar.startOfDay(for: times.end)
        ).day ?? 0

        return dayOffset > 0
    }
}
