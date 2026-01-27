import Foundation
import SwiftUI

/// نموذج ملاحظة اليوم (Day Note)
/// تم التبسيط: نص فقط، بدون تصنيفات أو شارات
struct Achievement: Identifiable, Codable, Equatable {
    var id = UUID()
    let date: Date           // التاريخ الذي اختاره المستخدم
    var title: String        // العنوان
    var note: String         // التفاصيل
    var category: AchievementCategory  // يُحفظ للتوافقية مع البيانات القديمة
    var imagePath: String?   // مسار الصورة
    var createdAt: Date = Date()

    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - التصنيفات (مُبسّطة - للتوافقية فقط)
enum AchievementCategory: String, Codable, CaseIterable {
    case note = "note"  // التصنيف الافتراضي الوحيد المستخدم الآن

    // Legacy categories - kept for data compatibility
    case work = "work"
    case personal = "personal"
    case overtime = "overtime"
    case task = "task"

    var localizedName: String {
        let isArabic = UserSettingsStore.shared.language == .arabic
        return isArabic ? "ملاحظة" : "Note"
    }

    var icon: String {
        return "note.text"
    }

    var color: Color {
        return ShiftTheme.ColorToken.brandPrimary
    }
}

// MARK: - Helpers
extension Achievement {
    var hasImage: Bool {
        guard let path = imagePath else { return false }
        return !path.isEmpty
    }

    static var placeholder: Achievement {
        Achievement(
            date: Date(),
            title: "Day Note",
            note: "Notes for the day...",
            category: .note
        )
    }
}
