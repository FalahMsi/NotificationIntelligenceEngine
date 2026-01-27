import Foundation

/// TimeShiftSystemProtocol
/// العقد الرسمي لأي نظام نوبات زمني (مثل 12/12 ، 24/48)
///
/// ❗️لا يعتمد على التقسيم اليومي
/// ❗️يُستخدم فقط لإنتاج TimeShiftTimeline
protocol TimeShiftSystemProtocol {

    // MARK: - Metadata

    /// الاسم المعروض للنظام (UI only)
    var systemName: String { get }

    /// مدة العمل بالساعات
    var workDurationHours: Int { get }

    /// مدة الراحة بالساعات
    var restDurationHours: Int { get }

    // MARK: - Engine

    /// بناء الخط الزمني الزمني (مقاطع وقت فعلية)
    ///
    /// - Parameters:
    ///   - startDate: تاريخ المرجع
    ///   - startTime: وقت بدء أول دوام
    ///   - periods: عدد الفترات المطلوب توليدها
    func buildTimeline(
        startDate: Date,
        startTime: DateComponents,
        periods: Int
    ) -> TimeShiftTimeline
}
