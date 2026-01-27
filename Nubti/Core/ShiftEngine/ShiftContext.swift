import Foundation

// MARK: - Flexibility Rules (The Brain Configuration)
/// قواعد المرونة: تحدد كيف يتعامل النظام مع التأخير، الاستئذان، وصافي الساعات.
struct ShiftFlexibilityRules: Codable, Hashable {
    /// دقائق التأخير المسموحة (Grace Period) قبل بدء الخصم (مثلاً: 15 دقيقة)
    var allowedLateEntryMinutes: Int = 0
    
    /// دقائق الاستراحة غير المدفوعة (تخصم من صافي الساعات)
    var breakDurationMinutes: Int = 0
    
    /// هل النظام مرن؟ (إذا نعم: الحضور المتأخر يزاح لوقت الخروج، إذا لا: الخروج ثابت)
    var isFlexibleTime: Bool = false
    
    /// هل يتم حساب العمل الإضافي (Overtime)؟
    var calculateOvertime: Bool = false
    
    // القيم الافتراضية للبداية
    static let standard = ShiftFlexibilityRules()
}

// MARK: - ShiftContext
/// وعاء الإعدادات: يحمل "ساعة الصفر" ومرجع الدورة وقواعد المرونة.
/// V3: أضيف دعم المنطقة الزمنية (timeZone)
struct ShiftContext: Codable, Hashable {
    let systemID: ShiftSystemID
    let startPhase: ShiftPhase? // للإصدارات القديمة (Backward Compatibility)

    // ✅ المتغير الأهم لضبط الجدول الدوري (يحدد أي يوم في الدورة نحن الآن)
    let setupIndex: Int?

    // ✅ ساعة الصفر: وقت البدء الذي يحدده المستخدم (المرساة)
    let shiftStartTime: DateComponents

    // ✅ مدة العمل بالساعات (للأنظمة التي تسمح بتحديد المستخدم مثل Morning)
    // إذا كانت nil، يستخدم النظام المدة الافتراضية من ShiftSystemProtocol.duration()
    let workDurationHours: Int?

    // تاريخ المرجع لضبط الدورة
    let referenceDate: Date

    // قواعد المرونة والتعامل مع الزمن
    let flexibility: ShiftFlexibilityRules

    // V3: المنطقة الزمنية (اختياري، الافتراضي: TimeZone.current)
    let timeZone: TimeZone?

    // MARK: - Helper Accessor 🧠
    /// مساعد سريع لجلب "ساعة الصفر" (Base Anchor Hour) لاستخدامها في المحرك
    var baseStartHour: Int {
        return shiftStartTime.hour ?? 7
    }

    enum CodingKeys: String, CodingKey {
        case systemID
        case startPhase
        case setupIndex
        case startHour
        case startMinute
        case workDurationHours
        case referenceDate
        case flexibility
        case timeZoneIdentifier // V3
    }

    // MARK: - Init
    init(
        systemID: ShiftSystemID,
        startPhase: ShiftPhase?,
        setupIndex: Int? = nil,
        shiftStartTime: DateComponents,
        referenceDate: Date,
        flexibility: ShiftFlexibilityRules = .standard,
        workDurationHours: Int? = nil,
        timeZone: TimeZone? = nil // V3: الافتراضي nil = TimeZone.current
    ) {
        self.systemID = systemID
        self.startPhase = startPhase
        self.setupIndex = setupIndex
        self.shiftStartTime = shiftStartTime
        self.workDurationHours = workDurationHours

        // تطهير التاريخ ليكون بداية اليوم دائماً لضمان دقة الحسابات
        // IMPORTANT: Use the specified timezone (or current) to normalize the date,
        // NOT Calendar.current which may have a different timezone.
        // This ensures consistent behavior when user travels between timezones.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone ?? .current
        self.referenceDate = calendar.startOfDay(for: referenceDate)

        self.flexibility = flexibility
        self.timeZone = timeZone
    }

    // MARK: - Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        systemID = try container.decode(ShiftSystemID.self, forKey: .systemID)
        startPhase = try container.decodeIfPresent(ShiftPhase.self, forKey: .startPhase)
        setupIndex = try container.decodeIfPresent(Int.self, forKey: .setupIndex)
        referenceDate = try container.decode(Date.self, forKey: .referenceDate)

        // استرجاع وقت البداية (يدعم النسخ القديمة والجديدة)
        let hour = try container.decode(Int.self, forKey: .startHour)
        let minute = try container.decode(Int.self, forKey: .startMinute)
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        shiftStartTime = comps

        // ✅ استرجاع مدة العمل (nil للنسخ القديمة = يستخدم النظام المدة الافتراضية)
        workDurationHours = try container.decodeIfPresent(Int.self, forKey: .workDurationHours)

        // استرجاع قواعد المرونة (مع قيمة افتراضية للنسخ القديمة)
        flexibility = try container.decodeIfPresent(ShiftFlexibilityRules.self, forKey: .flexibility) ?? .standard

        // V3: استرجاع المنطقة الزمنية (nil للنسخ القديمة = TimeZone.current)
        if let tzIdentifier = try container.decodeIfPresent(String.self, forKey: .timeZoneIdentifier) {
            timeZone = TimeZone(identifier: tzIdentifier)
        } else {
            timeZone = nil
        }
    }

    // MARK: - Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(systemID, forKey: .systemID)
        try container.encodeIfPresent(startPhase, forKey: .startPhase)
        try container.encodeIfPresent(setupIndex, forKey: .setupIndex)
        try container.encode(referenceDate, forKey: .referenceDate)

        // تفكيك الوقت للحفظ بشكل بسيط
        try container.encode(shiftStartTime.hour ?? 7, forKey: .startHour)
        try container.encode(shiftStartTime.minute ?? 0, forKey: .startMinute)

        // ✅ حفظ مدة العمل (إن وجدت)
        try container.encodeIfPresent(workDurationHours, forKey: .workDurationHours)

        try container.encode(flexibility, forKey: .flexibility)

        // V3: حفظ المنطقة الزمنية (إن وجدت)
        try container.encodeIfPresent(timeZone?.identifier, forKey: .timeZoneIdentifier)
    }
}