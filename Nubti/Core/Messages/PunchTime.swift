import Foundation

/// PunchTime
/// يمثل وقت بصمة واحد (دخول / تواجد / انصراف / إنجاز).
/// يُستخدم في التنبيهات (NotificationService) وجدولة المهام وعرض المواعيد.
struct PunchTime: Identifiable, Equatable, Sendable {

    // MARK: - Identity
    
    /// المعرف الفريد يعتمد على النوع والوقت الفعلي لضمان عدم تكرار التنبيهات لنفس الحدث
    var id: String {
        // استخدام Int لتمثيل الوقت بالثواني يجعل الـ ID مستقراً وفريداً وصغيراً
        "\(type.rawValue)-\(Int(date.timeIntervalSince1970))"
    }

    // MARK: - Core Properties

    /// نوع البصمة (دخول، تواجد، انصراف، إنجاز، أو تنبيه مسبق)
    let type: PunchType

    /// وقت تنفيذ البصمة الفعلي (يشمل التاريخ والوقت بدقة)
    let date: Date

    // MARK: - Init

    init(
        type: PunchType,
        date: Date
    ) {
        self.type = type
        self.date = date
    }

    // MARK: - Computed Properties (Optimized)
    
    /// عرض الوقت بصيغة مقروءة 24 ساعة (مثلاً 07:00 أو 23:30)
    var formattedTime: String {
        Self.timeFormatter.string(from: date)
    }
    
    /// خاصية لمعرفة إذا كان وقت البصمة قد فات (مفيد لتجنب جدولة إشعارات قديمة)
    var isPast: Bool {
        date < Date()
    }
    
    /// يعطي التاريخ المختصر ليوم البصمة (مفيد للفحص السريع والتجميع)
    var dayIdentifier: String {
        Self.dateFormatter.string(from: date)
    }

    // MARK: - Performance Optimization (Static Formatters)
    // إنشاء DateFormatter مكلف، لذا نستخدم نسخاً ثابتة (Static)
    
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX") // لضمان ثبات الأرقام الإنجليزية
        return f
    }()
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
