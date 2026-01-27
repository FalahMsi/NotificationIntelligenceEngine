import Foundation

/// TimePhase
/// مرحلة زمنية مجردة داخل اليوم
/// تُستخدم فقط في الأنظمة الزمنية (12/12، 24/48)
enum TimePhase: Equatable, Identifiable {

    case work
    case rest

    // MARK: - Identifiable
    var id: String { key }

    // MARK: - Stable Key
    var key: String {
        switch self {
        case .work: return "work"
        case .rest: return "rest"
        }
    }

    // MARK: - Flags

    /// هل هذا المقطع يُحسب كوقت دوام؟
    var isWorkingTime: Bool {
        self == .work
    }
}
