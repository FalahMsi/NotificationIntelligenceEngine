import SwiftUI

/// ManualLeaveEntryView
/// واجهة إدخال الإجازات (تدعم اللغتين والوضعين النهاري والليلي).
struct ManualLeaveEntryView: View {
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: UserSettingsStore
    @StateObject var viewModel = ManualLeaveViewModel()
    @Environment(\.colorScheme) var colorScheme
    
    // شبكة مرنة للأزرار
    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // 1. قسم اختيار الفترة (من - إلى)
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: tr("فترة الإجازة", "Leave Period"), icon: "calendar")
                        
                        VStack(spacing: 0) {
                            dateRow(title: tr("من تاريخ", "Start Date"), selection: $viewModel.startDate)
                            
                            Divider().overlay(Color.primary.opacity(0.1))
                            
                            dateRow(title: tr("إلى تاريخ", "End Date"), selection: $viewModel.endDate)
                        }
                        // تنسيق الكارت يدوياً لضمان عدم الاعتماد على extensions خارجية
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: ShiftTheme.Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: ShiftTheme.Radius.md)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                        
                        if viewModel.selectedDaysCount > 0 {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("\(tr("المدة", "Duration")): \(viewModel.selectedDaysCount) \(tr("يوم", "Days"))")
                            }
                            .font(.system(.caption, design: .rounded)).bold()
                            .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                            .padding(.horizontal, 8)
                            .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)

                    // 2. قسم نوع الإجازة
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: tr("نوع الإجازة", "Leave Type"), icon: "tag")
                        
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(ManualLeaveType.allCases) { type in
                                LeaveTypeCard(
                                    type: type,
                                    isSelected: viewModel.type == type,
                                    language: settings.language
                                )
                                .onTapGesture {
                                    HapticManager.shared.selection()
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                        viewModel.type = type
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                    
                    // 3. قسم الملاحظات
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: tr("ملاحظات (اختياري)", "Notes (Optional)"), icon: "pencil.line")
                        
                        TextField(tr("مثال: مراجعة، ظرف خاص...", "Example: Special circumstances..."), text: $viewModel.note)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: ShiftTheme.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: ShiftTheme.Radius.md)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                            .multilineTextAlignment(settings.language == .arabic ? .trailing : .leading)
                    }
                    .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical, 20)
            }
            .background(ShiftTheme.appBackground.ignoresSafeArea())
            .navigationTitle(tr("تسجيل إجازة", "Register Leave"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("إلغاء", "Cancel")) { dismiss() }
                        .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.isSaving {
                        ProgressView()
                    } else {
                        Button {
                            saveAndDismiss()
                        } label: {
                            Text(tr("حفظ", "Save")).bold()
                        }
                        .disabled(!viewModel.isValid)
                        .foregroundColor(viewModel.isValid ? ShiftTheme.ColorToken.brandPrimary : .secondary)
                    }
                }
            }
        }
        .environment(\.layoutDirection, settings.language.direction)
    }
    
    // MARK: - Components
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(.subheadline, design: .rounded))
        .fontWeight(.bold)
        .foregroundColor(.secondary)
        .padding(.horizontal, 4)
    }
    
    private func dateRow(title: String, selection: Binding<Date>) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            Spacer()
            DatePicker("", selection: selection, displayedComponents: .date)
                .labelsHidden()
                .accentColor(ShiftTheme.ColorToken.brandPrimary)
                // يضمن أن التقويم داخل الـ Picker يتبع لغة التطبيق وليس لغة الجهاز
                .environment(\.locale, Locale(identifier: settings.language.rawValue))
        }
        .padding(12)
    }
    
    private func saveAndDismiss() {
        viewModel.save()
        HapticManager.shared.notification(.success)
        dismiss()
    }
}

// MARK: - Subviews

struct LeaveTypeCard: View {
    let type: ManualLeaveType
    let isSelected: Bool
    let language: AppLanguage
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(type.color.opacity(isSelected ? (colorScheme == .dark ? 0.2 : 0.25) : 0.1))
                    .frame(width: 32, height: 32)
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(type.color)
                } else {
                    Circle()
                        .fill(type.color.opacity(0.6))
                        .frame(width: 8, height: 8)
                }
            }
            
            // ✅ استخدام localizedName لترجمة أسماء الإجازات ديناميكياً
            Text(type.localizedName)
                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .primary : .secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .background(
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(type.color.opacity(colorScheme == .dark ? 0.1 : 0.08))
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? type.color.opacity(0.6) : Color.primary.opacity(0.05), lineWidth: isSelected ? 1.5 : 1)
        )
        .shadow(
            color: isSelected ? type.color.opacity(0.2) : Color.black.opacity(colorScheme == .dark ? 0 : 0.03),
            radius: 8, y: 4
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
}
