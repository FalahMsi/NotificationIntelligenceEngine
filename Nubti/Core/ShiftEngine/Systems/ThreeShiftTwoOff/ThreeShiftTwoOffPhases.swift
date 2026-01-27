import Foundation

/// ThreeShiftOneOffPhases
/// تعريف الدورة الكاملة لنظام:
/// صباح → عصر → ليل → انصراف ليل → راحة → تكرار
///
/// المنطق المعتمد:
/// - 3 نوبات عمل
/// - انصراف بعد النوبة الليلية (يُحسب دوام)
/// - يوم راحة صريح
enum ThreeShiftOneOffPhases {

    /// الدورة المنطقية الثابتة للنظام
    static let cycle: [ShiftPhase] = [
        .morning,
        .evening,
        .night,
        .off,
        .off
    ]
}
