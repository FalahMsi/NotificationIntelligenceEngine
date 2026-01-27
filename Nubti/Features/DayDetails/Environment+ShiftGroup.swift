import SwiftUI

// MARK: - ShiftGroup Type
// تم التعديل: إضافة المجموعة D لدعم الأنظمة الرباعية + Identifiable.
public enum ShiftGroup: String, CaseIterable, Sendable, Identifiable {
    case a
    case b
    case c
    case d // تمت الإضافة لدعم الأنظمة التي تعتمد على 4 مجاميع

    public var id: String { rawValue }
    
    // اسم للعرض (يمكن تعريبه لاحقاً "المجموعة أ" إذا رغبت، حالياً الأحرف واضحة عالمياً)
    var displayName: String {
        return rawValue.uppercased()
    }
}

// MARK: - Environment Key
private struct ShiftGroupKey: EnvironmentKey {
    static let defaultValue: ShiftGroup = .a
}

public extension EnvironmentValues {
    var shiftGroup: ShiftGroup {
        get { self[ShiftGroupKey.self] }
        set { self[ShiftGroupKey.self] = newValue }
    }
}

// MARK: - View Convenience API
public extension View {
    func shiftGroup(_ group: ShiftGroup) -> some View {
        environment(\.shiftGroup, group)
    }
}
