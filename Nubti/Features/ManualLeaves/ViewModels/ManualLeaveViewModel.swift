import Foundation
import SwiftUI
import Combine

@MainActor
final class ManualLeaveViewModel: ObservableObject {

    // MARK: - View State
    @Published var type: ManualLeaveType = .regularLeave
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date()
    @Published var note: String = ""
    @Published var isSaving: Bool = false

    // MARK: - Dependencies
    private let store = ManualLeaveStore.shared
    
    // التقويم يتبع إعدادات المستخدم (ليس مثبتاً على "ar" فقط)
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: UserSettingsStore.shared.language.rawValue)
        return cal
    }

    // MARK: - Validation
    var isValid: Bool {
        calendar.startOfDay(for: startDate) <= calendar.startOfDay(for: endDate)
    }

    var selectedDaysCount: Int {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1
    }

    // MARK: - Actions

    func save() {
        guard isValid else { return }
        isSaving = true
        
        // تجهيز البيانات
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        
        let newLeave = ManualLeave(
            startDate: start,
            endDate: end,
            type: type,
            note: note.isEmpty ? nil : note
        )
        
        // الحفظ (الـ Store سيتولى التخزين وإرسال رسالة النظام وتحديث الإشعارات)
        store.saveLeave(newLeave)
        
        // إنهاء العملية
        isSaving = false
        reset()
    }

    func reset() {
        type = .regularLeave
        let today = calendar.startOfDay(for: Date())
        self.startDate = today
        self.endDate = today
        self.note = ""
    }
}
