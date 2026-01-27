import UIKit

/// PDFDataPreparer
/// طبقة تحضير البيانات لتقارير PDF.
/// مسؤولة عن الترتيب، التجميع حسب الشهر، والتحقق من الصور.
enum PDFDataPreparer {

    // MARK: - Month Group Model

    /// مجموعة ملاحظات شهر واحد
    struct MonthGroup: Identifiable {
        let id = UUID()
        let monthDate: Date           // تاريخ يمثل الشهر (أول يوم في الشهر)
        let monthTitle: String        // عنوان الشهر المنسق
        var achievements: [Achievement]

        var isEmpty: Bool { achievements.isEmpty }
    }

    // MARK: - Render Item Model

    /// عنصر قابل للعرض في قائمة الانتظار
    enum RenderItem {
        case monthHeader(title: String, date: Date)
        case dayNote(achievement: Achievement, validatedImage: UIImage?)
    }

    // MARK: - Sorting

    /// ترتيب الملاحظات من الأقدم للأحدث
    static func sortChronologically(_ achievements: [Achievement]) -> [Achievement] {
        achievements.sorted { $0.date < $1.date }
    }

    // MARK: - Grouping by Month

    /// تجميع الملاحظات حسب الشهر
    static func groupByMonth(_ achievements: [Achievement]) -> [MonthGroup] {
        let calendar = Calendar.current
        var groups: [String: MonthGroup] = [:]

        for achievement in achievements {
            // استخراج مفتاح الشهر (yyyy-MM)
            let components = calendar.dateComponents([.year, .month], from: achievement.date)
            guard let year = components.year, let month = components.month else { continue }
            let key = "\(String(year))-\(String(format: "%02d", month))"

            // إنشاء تاريخ أول يوم في الشهر
            let monthDate = calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? achievement.date

            if var existingGroup = groups[key] {
                existingGroup.achievements.append(achievement)
                groups[key] = existingGroup
            } else {
                let title = PDFDesignHelper.formatMonthTitle(monthDate)
                groups[key] = MonthGroup(
                    monthDate: monthDate,
                    monthTitle: title,
                    achievements: [achievement]
                )
            }
        }

        // ترتيب المجموعات حسب التاريخ وترتيب الملاحظات داخل كل مجموعة
        return groups.values
            .map { group in
                var sortedGroup = group
                sortedGroup.achievements = sortChronologically(sortedGroup.achievements)
                return sortedGroup
            }
            .sorted { $0.monthDate < $1.monthDate }
    }

    // MARK: - Image Validation

    /// تحميل والتحقق من صورة الملاحظة
    static func validateAndLoadImage(for achievement: Achievement) -> UIImage? {
        guard let path = achievement.imagePath, !path.isEmpty else {
            return nil
        }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsURL.appendingPathComponent(path)

        guard let data = try? Data(contentsOf: imageURL),
              let image = UIImage(data: data) else {
            // تسجيل تحذير إذا كان المسار موجوداً لكن الصورة غير صالحة
            PDFLogger.warning("Image not found or corrupt at path: \(path)")
            return nil
        }

        return image
    }

    // MARK: - Build Render Queue

    /// بناء قائمة انتظار العناصر القابلة للعرض
    /// تقوم بترتيب الملاحظات، تجميعها حسب الشهر، والتحقق من الصور
    static func buildRenderQueue(from achievements: [Achievement]) -> [RenderItem] {
        var queue: [RenderItem] = []

        // 1. ترتيب وتجميع
        let groups = groupByMonth(achievements)

        // 2. بناء قائمة الانتظار
        for group in groups {
            // تخطي المجموعات الفارغة
            guard !group.isEmpty else { continue }

            // إضافة عنوان الشهر
            queue.append(.monthHeader(title: group.monthTitle, date: group.monthDate))

            // إضافة الملاحظات مع صورها المتحقق منها
            for achievement in group.achievements {
                let validatedImage = validateAndLoadImage(for: achievement)
                queue.append(.dayNote(achievement: achievement, validatedImage: validatedImage))
            }
        }

        return queue
    }

    // MARK: - Statistics

    /// إحصائيات سريعة عن البيانات
    struct DataStats {
        let totalNotes: Int
        let notesWithImages: Int
        let monthCount: Int
    }

    static func calculateStats(from achievements: [Achievement]) -> DataStats {
        let groups = groupByMonth(achievements)
        let withImages = achievements.filter { $0.hasImage }.count

        return DataStats(
            totalNotes: achievements.count,
            notesWithImages: withImages,
            monthCount: groups.count
        )
    }
}
