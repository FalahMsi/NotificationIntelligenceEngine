import Foundation
import SwiftUI

/// ShiftPhase
/// يمثل الحالات المختلفة للنوبات (صباح، عصر، ليل) وأيام الراحة والإجازات.
/// تم التحديث: تم تجريده من منطق الوقت ليكون مجرد "هوية" (Identity Only).
enum ShiftPhase: String, Identifiable, Codable, Hashable, CaseIterable {

    // MARK: - Core Phases
    case morning, evening, night
    case off
    case weekend
    case leave

    // MARK: - Internal / Technical
    case firstOff, secondOff

    var id: String { rawValue }

    // MARK: - 🔑 Single Source of Truth (Display Name)

    /// الاسم المعروض الموحد في كامل التطبيق
    var displayName: String {
        let language = UserSettingsStore.shared.language

        switch self {
        case .morning:
            return language == .arabic ? "دوام صباح" : "Morning Shift"
        case .evening:
            return language == .arabic ? "دوام عصر" : "Evening Shift"
        case .night:
            return language == .arabic ? "دوام ليل" : "Night Shift"
        case .off:
            return language == .arabic ? "يوم راحة" : "Day Off"
        case .firstOff:
            return language == .arabic ? "راحة (1)" : "First Off"
        case .secondOff:
            return language == .arabic ? "راحة (2)" : "Second Off"
        case .weekend:
            return language == .arabic ? "عطلة" : "Weekend"
        case .leave:
            return language == .arabic ? "إجازة" : "Leave"
        }
    }

    /// Alias للحفاظ على التوافق
    var title: String {
        displayName
    }

    // MARK: - UI Helpers

    var iconName: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night:   return "moon.zzz.fill"
        case .leave:   return "suitcase.fill"
        default:       return "calendar.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .morning: return .orange
        case .evening: return .purple
        case .night:   return .blue
        case .off, .firstOff, .secondOff, .weekend:
            return .gray
        case .leave:
            return .red
        }
    }

    // MARK: - Logic Flags

    var isCountedAsWorkDay: Bool {
        switch self {
        case .morning, .evening, .night:
            return true
        default:
            return false
        }
    }

    var isVisibleInCalendar: Bool {
        switch self {
        case .firstOff, .secondOff:
            return false
        default:
            return true
        }
    }
    
    // ⚠️ تم حذف منطق الوقت (Offsets, StartTime, EndTime) من هنا.
    // ✅ المسؤولية انتقلت الآن إلى ShiftSystemProtocol والأنظمة المحددة.
}