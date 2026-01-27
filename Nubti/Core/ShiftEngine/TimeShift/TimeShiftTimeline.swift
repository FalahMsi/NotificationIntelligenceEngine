import Foundation

/// TimeShiftTimeline
/// ⏱️ ناتج الحساب الزمني التفصيلي داخل اليوم
///
/// يُستخدم في:
/// - التنبيهات
/// - البصمة (دخول / تواجد / خروج)
///
/// ❗️يظهر فقط في الأنظمة الزمنية
/// ❗️لا يُستخدم للتقويم أو الإجازات
struct TimeShiftTimeline {

    /// المقاطع الزمنية المحسوبة بالترتيب
    let items: [Item]

    /// مقطع زمني واحد داخل يوم (أو عابر لليوم)
    struct Item: Identifiable {

        /// معرف فريد
        let id = UUID()

        /// وقت البداية الفعلي
        let start: Date

        /// وقت النهاية الفعلي
        let end: Date

        /// نوع المقطع الزمني
        let phase: TimePhase

        /// هل هذا المقطع يُحسب كدوام؟
        /// (مهم للتنبيهات والبصمة)
        var isWorkingTime: Bool {
            phase.isWorkingTime
        }
    }
}
