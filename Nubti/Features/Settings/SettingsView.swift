import SwiftUI
import EventKit

/// SettingsView
/// واجهة الإعدادات المركزية: التحكم بالمظهر، الإشعارات، والتقارير.
struct SettingsView: View {
    
    // MARK: - Dependencies
    @ObservedObject var settings: UserSettingsStore
    @StateObject private var calendarService = SystemCalendarService.shared
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Notification Toggles (Direct Binding to UserDefaults)
    @AppStorage("enable_pre_shift_7h") var enablePreShift = true
    @AppStorage("enable_punch_in") var enablePunchIn = true
    @AppStorage("enable_presence_punch") var enablePresence = true
    @AppStorage("enable_punch_out") var enablePunchOut = true
    @AppStorage("enable_achievement") var enableAchievement = true
    
    // MARK: - State
    @State private var showLeaveSummary = false
    
    private var shiftContext: ShiftContext? {
        UserShift.shared.shiftContext
    }
    
    init(settings: UserSettingsStore) {
        self.settings = settings
    }
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // MARK: - 1. مظهر التطبيق
                    SectionHeader(title: tr("مظهر التطبيق", "App Appearance"), language: settings.language)
                    
                    HStack(spacing: 12) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            AppearanceOptionButton(
                                mode: mode,
                                isSelected: settings.appearanceMode == mode,
                                language: settings.language
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    settings.appearanceMode = mode
                                }
                                HapticManager.shared.selection()
                            }
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                    )
                    
                    // MARK: - 2. إعدادات الوقت
                    SectionHeader(title: tr("إعدادات الدورة الزمانية", "Time Cycle Settings"), language: settings.language)
                    
                    SettingsSectionContainer {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                IconBadge(icon: "clock.fill", color: .orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tr("وقت مرجع الصباح", "Morning Reference Time"))
                                        .font(.system(.subheadline, design: .rounded)).bold()
                                    Text(tr("يُستخدم لحساب كافة النوبات", "Used for all shift calculations"))
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text("\(settings.workStartHour):00")
                                    .font(.system(.subheadline, design: .rounded).bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange.opacity(0.12))
                                    .foregroundColor(.orange)
                                    .cornerRadius(8)
                            }
                            
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "info.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue.opacity(0.8))
                                Text(tr("لضمان دقة الحسابات، يرجى دائماً ضبط الوقت بناءً على بداية 'نوبة الصباح' في جهة عملك.", "To ensure accuracy, please set the time based on the 'Morning Shift' start at your workplace."))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    // MARK: - 3. الإشعارات
                    SectionHeader(title: tr("الإشعارات والذكاء الاصطناعي", "Notifications & AI"), language: settings.language)
                    
                    SettingsSectionContainer {
                        VStack(spacing: 0) {
                            Toggle(isOn: $settings.notificationsEnabled) {
                                HStack(spacing: 12) {
                                    IconBadge(icon: "bell.badge.fill", color: ShiftTheme.ColorToken.brandPrimary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tr("تفعيل تنبيهات البصمة", "Enable Punch Alerts"))
                                            .font(.system(.subheadline, design: .rounded)).bold()
                                        Text(tr("جدولة ذكية حسب نوبتك الحالية", "Smart scheduling based on your shift"))
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .tint(ShiftTheme.ColorToken.brandPrimary)
                            .padding(.vertical, 4)
                            .onChange(of: settings.notificationsEnabled) { _, _ in triggerRefresh() }
                            
                            if settings.notificationsEnabled {
                                VStack(spacing: 0) {
                                    Divider().overlay(Color.primary.opacity(0.08)).padding(.vertical, 12)
                                    
                                    DetailedToggleRow(title: tr("تنبيه الاستعداد (قبل الدوام بـ ٧ ساعات)", "Preparation (7h before shift)"), isOn: $enablePreShift, onToggle: triggerRefresh)
                                    DetailedToggleRow(title: tr("بصمة الدخول (قبل الدوام بـ ١٠ دقائق)", "Punch In (10m before shift)"), isOn: $enablePunchIn, onToggle: triggerRefresh)
                                    DetailedToggleRow(title: tr("بصمة التواجد (بعد ساعتين ودقيقة)", "Presence (2h 1m after start)"), isOn: $enablePresence, onToggle: triggerRefresh)
                                    DetailedToggleRow(title: tr("بصمة الانصراف (عند انتهاء الدوام)", "Punch Out (At shift end)"), isOn: $enablePunchOut, onToggle: triggerRefresh)
                                    DetailedToggleRow(title: tr("سجل الإنجاز (بعد الانصراف مباشرة)", "Achievement Log (After shift)"), isOn: $enableAchievement, onToggle: triggerRefresh)
                                }
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                    
                    // MARK: - 4. التكامل والتقارير
                    SectionHeader(title: tr("التكامل والتقارير", "Integration & Reports"), language: settings.language)
                    
                    VStack(spacing: 12) {
                        Button { handleCalendarAction() } label: {
                            SettingsCard(
                                icon: "calendar",
                                iconColor: calendarStatusColor,
                                title: tr("تقويم الجهاز", "Device Calendar"),
                                subtitle: tr("مزامنة العطل الرسمية والمناسبات", "Sync holidays & events"),
                                trailing: calendarStatusText,
                                trailingColor: calendarStatusColor,
                                language: settings.language
                            )
                        }
                        
                        NavigationLink { ManualLeavesListView() } label: {
                            SettingsCard(
                                icon: "calendar.badge.plus",
                                iconColor: .indigo,
                                title: tr("سجل الإجازات", "Leave Logs"),
                                subtitle: tr("إدارة إجازاتك اليدوية بدقة", "Manage manual leaves accurately"),
                                language: settings.language
                            )
                        }
                        
                        HStack(spacing: 12) {
                            SummaryButton(title: tr("ملخص الإجازات", "Leave Summary"), icon: "chart.bar.fill", color: .purple) {
                                showLeaveSummary = true
                            }
                            // يمكنك إضافة زر "أيام العمل" لاحقاً عند اكتمال العمل عليه
                        }
                    }
                    .buttonStyle(.plain)
                    
                    // MARK: - 5. معلومات النظام
                    SettingsSectionContainer {
                        HStack {
                            IconBadge(icon: "info.bubble.fill", color: .gray)
                            Text(tr("نظام النوبات النشط", "Active Shift System"))
                                .font(.system(.subheadline, design: .rounded)).bold()
                            Spacer()
                            Text(shiftContext?.systemID.title ?? tr("غير محدد", "Not Set"))
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(ShiftTheme.ColorToken.brandPrimary.opacity(0.12))
                                .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
            // ضبط الاتجاه العام للواجهة
            .environment(\.layoutDirection, settings.language.direction)
            .background(Color.clear)
            .navigationTitle(tr("الإعدادات", "Settings"))
        }
        .sheet(isPresented: $showLeaveSummary) {
            ManualLeavesSummarySheet().environmentObject(settings)
        }
    }
    
    // MARK: - Actions
    
    private func triggerRefresh() {
        HapticManager.shared.selection()
        if let context = shiftContext {
            // استدعاء مباشر، العملية تتم في الخلفية تلقائياً
            let overrides = UserShift.shared.allManualOverrides
            
            NotificationService.shared.rebuildShiftNotifications(
                context: context,
                manualOverrides: overrides
            )
        }
    }
    
    private var calendarStatusText: String {
        switch calendarService.authorizationStatus {
        case .fullAccess, .writeOnly: return tr("مفعل", "Active")
        case .denied, .restricted: return tr("مرفوض", "Denied")
        default: return tr("إعداد", "Setup")
        }
    }
    
    private var calendarStatusColor: Color {
        (calendarService.authorizationStatus == .fullAccess || calendarService.authorizationStatus == .writeOnly) ? .green : .secondary
    }
    
    private func handleCalendarAction() {
        if calendarService.authorizationStatus == .notDetermined {
            Task { await calendarService.requestAccessIfNeeded() }
        } else if calendarService.authorizationStatus == .denied {
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        }
    }
}

// MARK: - Reusable Components (Keep them here)
// (تم الإبقاء على المكونات الفرعية كما هي لأنها ممتازة)
struct SectionHeader: View {
    let title: String
    let language: AppLanguage
    
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: language == .arabic ? .trailing : .leading)
            .padding(.horizontal, 8)
            .padding(.bottom, -12)
    }
}

struct SettingsSectionContainer<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack { content }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.03), radius: 10, y: 4)
    }
}

struct IconBadge: View {
    let icon: String
    let color: Color
    
    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .black))
            .foregroundColor(color)
            .frame(width: 32, height: 32)
            .background(color.opacity(0.15))
            .clipShape(Circle())
    }
}

struct DetailedToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.primary.opacity(0.8))
        }
        .padding(.vertical, 8)
        .tint(ShiftTheme.ColorToken.brandPrimary)
        .onChange(of: isOn) { _, _ in onToggle() }
    }
}

struct SummaryButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.system(.caption, design: .rounded)).bold()
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.03), radius: 5, y: 2)
        }
    }
}

struct AppearanceOptionButton: View {
    let mode: AppearanceMode
    let isSelected: Bool
    let language: AppLanguage
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(background)
                        .frame(height: 54)
                        .shadow(color: isSelected ? ShiftTheme.ColorToken.brandPrimary.opacity(0.2) : Color.black.opacity(0.05), radius: 8, y: 4)
                    
                    Image(systemName: iconName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(isSelected ? iconColor : .secondary)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? ShiftTheme.ColorToken.brandPrimary : Color.primary.opacity(0.12), lineWidth: isSelected ? 2 : 1)
                )
                
                Text(mode.localizedName)
                    .font(.system(size: 11, weight: isSelected ? .black : .bold, design: .rounded))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var background: Color {
        switch mode {
        case .light:  return Color.white
        case .dark:   return Color(white: 0.15)
        case .system: return Color(white: 0.95)
        }
    }
    
    private var iconName: String {
        switch mode {
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.stars.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
    
    private var iconColor: Color {
        switch mode {
        case .light:  return .orange
        case .dark:   return .purple
        case .system: return .blue
        }
    }
}

struct SettingsCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    var trailing: String? = nil
    var trailingColor: Color = .secondary
    let language: AppLanguage
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.12))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(.callout, design: .rounded)).bold()
                Text(subtitle).font(.system(size: 10)).foregroundColor(.secondary)
            }
            Spacer()
            if let trailing = trailing {
                Text(trailing)
                    .font(.system(.caption, design: .rounded)).bold()
                    .foregroundColor(trailingColor)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(trailingColor.opacity(0.12))
                    .clipShape(Capsule())
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.secondary.opacity(0.5))
                    .flipsForRightToLeftLayoutDirection(true)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}
