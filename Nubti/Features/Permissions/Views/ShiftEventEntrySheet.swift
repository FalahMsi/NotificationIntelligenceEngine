import SwiftUI

/// ShiftEventEntrySheet
/// شيت سريع لإضافة استئذان أو تأخير.
/// تم التحديث: تثبيت التاريخ وتبسيط الواجهة.
struct ShiftEventEntrySheet: View {
    
    // MARK: - Inputs
    let eventType: ShiftEventType
    let initialDate: Date // التاريخ ممرر وثابت
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var settings: UserSettingsStore
    @ObservedObject var eventStore = ShiftEventStore.shared
    
    @State private var selectedMinutes: Int = 30
    @State private var note: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // قسم المعلومات الثابتة (للتأكيد فقط)
                Section {
                    HStack {
                        Text(tr("التاريخ", "Date"))
                        Spacer()
                        Text(initialDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(tr("النوع", "Type"))
                        Spacer()
                        Text(eventType.localizedName(language: settings.language))
                            .foregroundColor(.secondary)
                    }
                }
                
                // اختيار المدة
                Section(header: Text(tr("المدة", "Duration"))) {
                    Picker(tr("المدة بالدقائق", "Duration (Minutes)"), selection: $selectedMinutes) {
                        ForEach([15, 30, 45, 60, 90, 120, 180], id: \.self) { min in
                            Text("\(min) \(tr("دقيقة", "min"))").tag(min)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                }
                
                // الملاحظات
                Section(header: Text(tr("ملاحظة (اختياري)", "Note (Optional)"))) {
                    TextField(tr("اكتب سبب الاستئذان...", "Reason..."), text: $note)
                }
            }
            .navigationTitle(eventType.localizedName(language: settings.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("إلغاء", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("حفظ", "Save")) {
                        saveEvent()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .environment(\.layoutDirection, settings.language.direction)
    }
    
    private func saveEvent() {
        let event = ShiftEvent(
            date: initialDate,
            type: eventType,
            durationMinutes: selectedMinutes,
            note: note
        )
        eventStore.add(event)
        
        // تحديث التنبيهات
        if let context = UserShift.shared.shiftContext {
            NotificationService.shared.rebuildShiftNotifications(
                context: context,
                manualOverrides: UserShift.shared.allManualOverrides
            )
        }
        
        HapticManager.shared.notification(.success)
        dismiss()
    }
}
