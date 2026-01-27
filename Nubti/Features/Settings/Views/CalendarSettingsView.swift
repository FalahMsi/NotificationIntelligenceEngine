import SwiftUI
import EventKit

struct CalendarSettingsView: View {
    
    // MARK: - Dependencies
    @EnvironmentObject private var settings: UserSettingsStore
    @StateObject private var calendarService = SystemCalendarService.shared
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // 1. الخلفية التكيفية
            ShiftTheme.appBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // MARK: - كرت حالة الوصول (Integration Status)
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel(title: tr("تكامل النظام", "System Integration"), icon: "shield.fill")
                        
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(statusColor.opacity(colorScheme == .dark ? 0.15 : 0.12))
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: statusIcon)
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(statusColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(tr("حالة الوصول للتقويم", "Calendar Access Status"))
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text(statusText)
                                    .font(.system(.subheadline, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(statusColor)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                    
                    // MARK: - كرت التحكم (Integration Toggle)
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel(title: tr("خيارات العرض", "Display Options"), icon: "slider.horizontal.3")
                        
                        VStack(spacing: 16) {
                            Toggle(isOn: Binding(
                                get: { settings.systemCalendarIntegrationEnabled },
                                set: { newValue in
                                    HapticManager.shared.selection()
                                    handleToggleChange(newValue)
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tr("جلب العطل الرسمية", "Fetch Public Holidays"))
                                        .font(.system(.headline, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    
                                    Text(tr("عرض المناسبات الوطنية والدينية في التقويم", "Display national & religious events in calendar"))
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .tint(ShiftTheme.ColorToken.brandPrimary)
                            .disabled(isToggleDisabled)
                            
                            if isToggleDisabled {
                                divider
                                
                                Button(action: openSystemSettings) {
                                    HStack {
                                        Image(systemName: "gearshape.fill")
                                        Text(tr("تغيير الصلاحية من الإعدادات", "Change Permission in Settings"))
                                    }
                                    .font(.system(.subheadline, design: .rounded)).bold()
                                    .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                    
                    // MARK: - صندوق المعلومات (Info Box)
                    descriptionBox
                    
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                .padding(.top, 20)
            }
        }
        .navigationTitle(tr("تقويم الجهاز", "Device Calendar"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, settings.language.direction)
    }
    
    // MARK: - Logic Implementation
    
    private func handleToggleChange(_ enabled: Bool) {
        switch calendarService.authorizationStatus {
        case .notDetermined:
            Task {
                await calendarService.requestAccessIfNeeded()
                await MainActor.run {
                    // Update based on the result of the request
                    if calendarService.authorizationStatus == .fullAccess || calendarService.authorizationStatus == .writeOnly {
                         settings.systemCalendarIntegrationEnabled = true
                    } else {
                         settings.systemCalendarIntegrationEnabled = false
                    }
                }
            }
        case .authorized, .fullAccess, .writeOnly:
            settings.systemCalendarIntegrationEnabled = enabled
        case .denied, .restricted:
            settings.systemCalendarIntegrationEnabled = false
            openSystemSettings()
        @unknown default:
            settings.systemCalendarIntegrationEnabled = false
        }
    }
    
    // MARK: - Helpers
    
    private func sectionLabel(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(.system(size: 13, weight: .black, design: .rounded))
        .foregroundColor(.secondary)
        .padding(.horizontal, 4)
    }
    
    private var divider: some View {
        Divider().overlay(Color.primary.opacity(0.05))
    }
    
    private var descriptionBox: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue.opacity(0.8))
                .font(.title3)
            
            Text(infoText)
                .font(.system(.caption, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineSpacing(4)
                .multilineTextAlignment(settings.language == .arabic ? .trailing : .leading)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: settings.language == .arabic ? .trailing : .leading)
        .background(Color.blue.opacity(colorScheme == .dark ? 0.05 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: ShiftTheme.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ShiftTheme.Radius.md)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var isToggleDisabled: Bool {
        calendarService.authorizationStatus == .denied || calendarService.authorizationStatus == .restricted
    }
    
    private var statusIcon: String {
        switch calendarService.authorizationStatus {
        case .authorized, .fullAccess: return "checkmark.shield.fill"
        case .denied, .restricted: return "xmark.shield.fill"
        default: return "shield.fill"
        }
    }
    
    private var statusText: String {
        switch calendarService.authorizationStatus {
        case .authorized, .fullAccess: return tr("مفعل", "Active")
        case .writeOnly: return tr("وصول محدود", "Limited Access")
        case .denied, .restricted: return tr("مرفوض", "Denied")
        case .notDetermined: return tr("غير محدد", "Not Determined")
        @unknown default: return tr("غير معروف", "Unknown")
        }
    }
    
    private var statusColor: Color {
        switch calendarService.authorizationStatus {
        case .authorized, .fullAccess: return .green
        case .writeOnly: return .orange
        case .denied, .restricted: return .red
        default: return .secondary
        }
    }
    
    private var infoText: String {
        if isToggleDisabled {
            return tr("تم رفض الوصول للتقويم. يرجى تفعيله من إعدادات النظام لتتمكن MyShift من عرض العطل الرسمية والمناسبات.", "Calendar access denied. Please enable it in System Settings so MyShift can display holidays and events.")
        }
        return tr("يتم استخدام هذه الصلاحية فقط لجلب الأحداث والعطل من تقويم Apple الخاص بك وعرضها داخل التقويم الخاص بنا.", "This permission is only used to fetch events and holidays from your Apple Calendar and display them within our calendar.")
    }
    
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
