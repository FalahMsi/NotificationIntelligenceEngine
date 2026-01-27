import Foundation

/// EightHourShiftPhases
/// تعريف الدورة الكاملة لنظام 8 ساعات
///
/// المنطق:
/// - 6 أيام عمل متتالية
/// - 2 أيام راحة
///
/// ❗️تفاصيل التوقيت (بداية الدوام) تأتي من ShiftContext
enum EightHourShiftPhases {

    /// الدورة المنطقية الثابتة للنظام
    static let cycle: [ShiftPhase] = [
        .morning,
        .morning,
        .evening,
        .evening,
        .night,
        .night,
        .off,
        .off
    ]
}
