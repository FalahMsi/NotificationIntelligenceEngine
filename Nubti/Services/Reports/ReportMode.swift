import Foundation

/// ReportMode
/// يحدد نوع التقرير المطلوب توليده.
/// يُستخدم في واجهة اختيار التقارير لتوجيه محرك الطباعة (PDF Engine) لنوع البيانات المطلوبة.
enum ReportMode: String, CaseIterable, Identifiable {

    case workOnly
    case achievementsOnly
    case unified

    var id: String { rawValue }

    // MARK: - Display (Friendly & Non-Formal)

    /// العنوان الرئيسي لكل وضع
    var title: String {
        let isArabic = UserSettingsStore.shared.language == .arabic
        
        switch self {
        case .workOnly:
            return isArabic ? "ملخص الدوام" : "Work Summary"
        case .achievementsOnly:
            return isArabic ? "سجل الإنجازات" : "Achievements Log"
        case .unified:
            return isArabic ? "التقرير الموحد" : "Unified Report"
        }
    }

    /// وصف فرعي يوضح للمستخدم ما سيحتويه التقرير
    var subtitle: String {
        let isArabic = UserSettingsStore.shared.language == .arabic
        
        switch self {
        case .workOnly:
            return isArabic ? "إحصائيات أيام العمل، الإجازات، وصافي الساعات" : "Work days, leaves, and net hours stats"
        case .achievementsOnly:
            return isArabic ? "استعراض كافة المهام والإنجازات التي وثقتها" : "Review all tasks and achievements logged"
        case .unified:
            return isArabic ? "عرض متكامل يجمع تفاصيل الدوام مع الإنجازات" : "Integrated view of work details and achievements"
        }
    }

    // MARK: - Icon (UI)

    /// أيقونة النظام (SF Symbols) المناسبة لكل نوع
    var systemImage: String {
        switch self {
        case .workOnly:
            return "calendar.badge.clock"
        case .achievementsOnly:
            return "sparkles"
        case .unified:
            return "doc.text.below.ecg.fill"
        }
    }

    // MARK: - Logic Helpers

    /// ترتيب افتراضي منطقي لعرض الخيارات في القوائم
    static var defaultOrder: [ReportMode] {
        [.unified, .workOnly, .achievementsOnly]
    }
}
