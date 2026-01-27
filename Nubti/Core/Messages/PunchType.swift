import Foundation
import SwiftUI

/// نوع البصمة المستخدمة في التنبيهات والجدولة والتقارير
public enum PunchType: String, Sendable, Codable, Equatable, CaseIterable {

    /// تنبيه مسبق (قبل الدوام بـ 7 ساعات)
    case preShift = "pre-7h"

    /// تذكير قبل اليوم (12 ساعة قبل الدوام) - V2/Phase 5
    case preDayReminder = "pre-day-12h"

    /// بصمة دخول
    case checkIn = "punch-in"

    /// بصمة تواجد (خلال الدوام)
    case presence = "punch-presence"

    /// بصمة انصراف
    case checkOut = "punch-out"
    
    /// سجل الإنجاز (إضافي للتوثيق)
    case achievement = "achievement"

    // MARK: - Localized Title
    // نستخدم UserDefaults مباشرة لتجنب مشاكل الـ MainActor عند الطلب من الخلفية
    public var title: String {
        let lang = UserDefaults.standard.string(forKey: "app_language") ?? "ar"
        let isArabic = lang == "ar"
        
        switch self {
        case .preShift:
            return isArabic ? "استعداد للدوام ⏳" : "Upcoming Shift ⏳"
        case .preDayReminder:
            return isArabic ? "تذكير قبل اليوم 🌙" : "Pre-Day Reminder 🌙"
        case .checkIn:
            return isArabic ? "بصمة دخول" : "Check In"
        case .presence:
            return isArabic ? "بصمة تواجد" : "Presence Check"
        case .checkOut:
            return isArabic ? "بصمة انصراف" : "Check Out"
        case .achievement:
            return isArabic ? "سجل الإنجاز" : "Achievement Log"
        }
    }
    
    // MARK: - UI Helpers
    
    public var iconName: String {
        switch self {
        case .preShift:        return "hourglass"
        case .preDayReminder:  return "moon.stars.fill"
        case .checkIn:         return "arrow.right.to.line.circle.fill"
        case .presence:        return "location.circle.fill"
        case .checkOut:        return "arrow.left.to.line.circle.fill"
        case .achievement:     return "star.circle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .preShift:        return .gray
        case .preDayReminder:  return .indigo
        case .checkIn:         return .green
        case .presence:        return .orange
        case .checkOut:        return .red
        case .achievement:     return .purple
        }
    }
}
