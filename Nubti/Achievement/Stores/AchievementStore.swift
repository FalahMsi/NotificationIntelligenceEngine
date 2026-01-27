import Foundation
import SwiftUI
import Combine
import os.log

/// AchievementStore
/// المسؤول عن إدارة وحفظ سجل الإنجازات والملاحظات مع دعم تنظيف الملفات المرفقة.
/// تم التدقيق: إضافة ميزة الحذف الفعلي للصور من القرص وتحسين أداء الاستعلام.
@MainActor
final class AchievementStore: ObservableObject {

    static let shared = AchievementStore()

    @Published private(set) var achievements: [Achievement] = []

    private let saveKey = "SavedAchievements"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app", category: "Achievements")

    private init() {
        load()
    }

    // MARK: - Queries (الاستعلام)

    /// جلب الإنجازات ليوم محدد بدقة عالية
    func achievements(for date: Date) -> [Achievement] {
        // استخدام تقويم يتبع لغة التطبيق لضمان توافق مقارنة الأيام
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: UserSettingsStore.shared.language.rawValue)
        let targetDate = calendar.startOfDay(for: date)
        
        return achievements.filter {
            calendar.isDate($0.date, inSameDayAs: targetDate)
        }
    }

    // MARK: - Mutations (الإضافة والتعديل والحذف)

    func add(_ achievement: Achievement) {
        achievements.append(achievement)
        sortAndSave()
    }

    func update(_ achievement: Achievement) {
        guard let index = achievements.firstIndex(where: { $0.id == achievement.id }) else {
            return
        }
        
        // إذا تغيرت الصورة أو حذفت، يجب تنظيف الملف القديم (تحسين مستقبلي)
        achievements[index] = achievement
        sortAndSave()
    }

    /// حذف إنجاز واحد مع تنظيف مرفقاته
    func delete(_ achievement: Achievement) {
        // 1. حذف ملف الصورة من القرص أولاً
        if let imagePath = achievement.imagePath {
            deleteImageFromDisk(path: imagePath)
        }
        
        // 2. حذف السجل من الذاكرة
        achievements.removeAll { $0.id == achievement.id }
        save()
    }

    /// حذف مجموعة إنجازات (يستخدم في القوائم) مع تنظيف المرفقات
    func delete(at indexSet: IndexSet) {
        for index in indexSet {
            let achievement = achievements[index]
            if let imagePath = achievement.imagePath {
                deleteImageFromDisk(path: imagePath)
            }
        }
        achievements.remove(atOffsets: indexSet)
        save()
    }

    // MARK: - Helpers (المساعدات التقنية)

    private func sortAndSave() {
        // ترتيب الإنجازات: الأحدث تاريخاً يظهر أولاً
        achievements.sort { $0.date > $1.date }
        save()
    }

    /// حذف ملف الصورة من مجلد المستندات لتوفير مساحة الجهاز
    private func deleteImageFromDisk(path: String) {
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(path)
        
        try? FileManager.default.removeItem(at: url)
        logger.info("🗑️ [AchievementStore] Deleted image file: \(path)")
    }

    // MARK: - Persistence (التخزين الدائم)

    private func save() {
        guard let encoded = try? JSONEncoder().encode(achievements) else { return }
        UserDefaults.standard.set(encoded, forKey: saveKey)
        // إخطار الواجهات بالتغيير فوراً
        objectWillChange.send()
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: saveKey),
            let decoded = try? JSONDecoder().decode([Achievement].self, from: data)
        else {
            return
        }
        self.achievements = decoded
    }
}
