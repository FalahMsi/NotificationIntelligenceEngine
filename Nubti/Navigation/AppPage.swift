import Foundation
import SwiftUI

/// AppPage
/// يمثل الصفحات الأساسية للتنقل السفلي (Bottom Bar).
/// هذا enum هو المصدر الوحيد لتعريف مسارات التنقل العليا.
enum AppPage: String, Hashable, CaseIterable {

    case calendar
    case updates
    case leaves
    case services
    case settings
    
    // صفحة إعداد الشفت (تُستخدم غالباً كـ Full Screen Cover وليس في التاب بار)
    case shiftSelection

    // MARK: - Display Properties
    
    /// العنوان المترجم للصفحة
    var title: String {
        let isArabic = UserDefaults.standard.string(forKey: "app_language") ?? "ar" == "ar"
        switch self {
        case .calendar:       return isArabic ? "التقويم" : "Calendar"
        case .updates:        return isArabic ? "سجل النشاط" : "Activity Log"
        case .leaves:         return isArabic ? "الإجازات" : "Leaves"
        case .services:       return isArabic ? "السجلات" : "Records"
        case .settings:       return isArabic ? "الإعدادات" : "Settings"
        case .shiftSelection: return isArabic ? "إعداد الشفت" : "Shift Setup"
        }
    }

    /// أيقونة النظام (SF Symbols)
    var icon: String {
        switch self {
        case .calendar:       return "calendar"
        case .updates:        return "clock.arrow.circlepath"
        case .leaves:         return "suitcase"
        case .services:       return "doc.text"
        case .settings:       return "gearshape"
        case .shiftSelection: return "clock.arrow.2.circlepath"
        }
    }
}
