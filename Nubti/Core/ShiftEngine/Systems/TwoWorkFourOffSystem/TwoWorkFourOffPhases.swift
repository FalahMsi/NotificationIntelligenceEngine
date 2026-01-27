import Foundation

/// TwoWorkFourOffPhases
/// تعريف الدورة الكاملة لنظام 48 / 96
///
/// المنطق:
/// - يومان عمل (48 ساعة)
/// - أربعة أيام راحة (96 ساعة)
/// - نظام دوري ثابت
///
/// ⚠️
/// - لا نوبات ليلية
/// - لا nightExit
/// - phase = .morning تعني "يوم عمل"
enum TwoWorkFourOffPhases {

    /// الدورة المنطقية الثابتة للنظام
    /// [عمل, عمل, راحة, راحة, راحة, راحة]
    static let cycle: [ShiftPhase] = [
        .morning,
        .morning,
        .off,
        .off,
        .off,
        .off
    ]
}
