import SwiftUI
import UserNotifications

/// NotificationsSettingsView (Simplified)
/// 3 إعدادات مسبقة فقط: إيقاف | أساسي | الكل
/// V3: Uses NotificationAdvancedConfig as Single Source of Truth
/// V4: State-aware test notification verification + iOS limitations disclaimer
/// - Permission status indicator
/// - Advanced settings section (collapsible)
/// - No more legacy UserDefaults writes
struct NotificationsSettingsView: View {
    @ObservedObject var settings: UserSettingsStore
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) var dismiss

    // MARK: - Single Preset Selection
    @AppStorage("notification_preset") var selectedPreset: String = NotificationPreset.essential.rawValue

    // MARK: - Permission Status (V2)
    @State private var permissionStatus: NotificationService.PermissionStatus = .unknown

    // MARK: - Advanced Settings (V2/Phase 4)
    @State private var showAdvancedSettings: Bool = false
    @State private var advancedConfig: NotificationAdvancedConfig = NotificationConfigStore.shared.load()

    // MARK: - Scheduled Notifications Preview (V3)
    @State private var scheduledCount: Int = 0
    @State private var upcomingNotifications: [(title: String, date: Date)] = []

    // MARK: - Test Notification State (V4)
    @State private var testNotificationState: NotificationService.TestNotificationState = .idle

    var currentPreset: NotificationPreset {
        NotificationPreset(rawValue: selectedPreset) ?? .essential
    }

    /// هل الصلاحيات مرفوضة أو غير محددة؟
    private var showPermissionWarning: Bool {
        permissionStatus == .denied || permissionStatus == .notDetermined
    }

    /// إظهار قسم الإعدادات المتقدمة فقط عند تفعيل التنبيهات
    private var showAdvancedSection: Bool {
        currentPreset != .off
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ShiftTheme.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {

                        headerSection

                        // V2: تحذير عند رفض الصلاحيات
                        if showPermissionWarning {
                            permissionWarningBanner
                        }

                        // 3 Presets
                        VStack(spacing: 12) {
                            ForEach(NotificationPreset.allCases, id: \.self) { preset in
                                PresetCard(
                                    preset: preset,
                                    isSelected: currentPreset == preset
                                ) {
                                    HapticManager.shared.selection()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        selectedPreset = preset.rawValue
                                    }
                                    applyPreset(preset)
                                }
                            }
                        }
                        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)

                        infoNote

                        // V3: Scheduled Notifications Preview
                        if showAdvancedSection && !upcomingNotifications.isEmpty {
                            scheduledNotificationsPreview
                        }

                        // V4: iOS Limitations Disclaimer
                        if showAdvancedSection {
                            iosLimitationsDisclaimer
                        }

                        // V2/Phase 4: قسم الإعدادات المتقدمة
                        if showAdvancedSection {
                            advancedSettingsSection
                        }
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(tr("التنبيهات", "Alerts"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(tr("تم", "Done")) { dismiss() }
                }
            }
            .onAppear {
                checkPermissionStatus()
                advancedConfig = NotificationConfigStore.shared.load()
                loadScheduledNotifications()
                setupTestNotificationObserver()
            }
            .onDisappear {
                // إعادة تعيين حالة الاختبار عند مغادرة الشاشة
                NotificationService.shared.resetTestNotificationState()
            }
        }
        .environment(\.layoutDirection, settings.language.direction)
    }

    // MARK: - Advanced Settings Section (V2/Phase 4)

    private var advancedSettingsSection: some View {
        VStack(spacing: 0) {
            // Header (Collapsible Toggle)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showAdvancedSettings.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)

                    Text(tr("إعدادات متقدمة", "Advanced Settings"))
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: showAdvancedSettings ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            // Expanded Content
            if showAdvancedSettings {
                VStack(spacing: 16) {

                    // Entry Offset Stepper
                    advancedRow(
                        icon: "arrow.right.to.line.circle.fill",
                        iconColor: .green,
                        title: tr("تنبيه الدخول", "Entry Alert"),
                        subtitle: tr(
                            "قبل \(advancedConfig.entry.primaryOffset) دقيقة",
                            "\(advancedConfig.entry.primaryOffset) min before"
                        )
                    ) {
                        Stepper("", value: $advancedConfig.entry.primaryOffset, in: 0...120, step: 5)
                            .labelsHidden()
                            .onChange(of: advancedConfig.entry.primaryOffset) { _, _ in
                                // V3: Save to unified config only
                                saveAndRebuild()
                            }
                    }

                    // Presence Offset (only for "All" preset)
                    if currentPreset == .all {
                        advancedRow(
                            icon: "location.circle.fill",
                            iconColor: .orange,
                            title: tr("تنبيه التواجد", "Presence Alert"),
                            subtitle: tr(
                                "بعد \(advancedConfig.presence.primaryOffset) دقيقة",
                                "\(advancedConfig.presence.primaryOffset) min after start"
                            )
                        ) {
                            Stepper("", value: $advancedConfig.presence.primaryOffset, in: 30...240, step: 15)
                                .labelsHidden()
                                .onChange(of: advancedConfig.presence.primaryOffset) { _, _ in
                                    // V3: Save to unified config only
                                    saveAndRebuild()
                                }
                        }
                    }

                    // Pre-Day Reminder Toggle (Phase 5)
                    advancedToggleRow(
                        icon: "moon.stars.fill",
                        iconColor: .indigo,
                        title: tr("تذكير قبل اليوم", "Pre-Day Reminder"),
                        subtitle: tr("قبل 12 ساعة من الدوام", "12 hours before shift"),
                        isOn: $advancedConfig.global.preDayReminderEnabled
                    )
                    .onChange(of: advancedConfig.global.preDayReminderEnabled) { _, _ in
                        saveAndRebuild()
                    }

                    // V3/Phase 2: Test Notification Button
                    testNotificationButton

                }
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
    }

    // MARK: - Test Notification Button (V4: State-Aware)

    private var testNotificationButton: some View {
        VStack(spacing: 8) {
            Button {
                guard case .idle = testNotificationState else { return }
                HapticManager.shared.impact(.medium)
                NotificationService.shared.sendTestNotification()
            } label: {
                HStack(spacing: 12) {
                    testNotificationIcon
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(testNotificationTitle)
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundColor(.primary)

                        Text(testNotificationSubtitle)
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    testNotificationTrailingIcon
                }
                .padding(12)
                .background(testNotificationBackgroundColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!isTestButtonEnabled)

            // V4: عرض رسالة التحذير عند الـ timeout
            if case .timeout = testNotificationState {
                testNotificationTimeoutWarning
            }
        }
    }

    /// أيقونة زر الاختبار حسب الحالة
    private var testNotificationIcon: some View {
        Group {
            switch testNotificationState {
            case .idle:
                Image(systemName: "bell.and.waves.left.and.right.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
            case .sending:
                ProgressView()
                    .scaleEffect(0.8)
            case .verified:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.red)
            case .timeout:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.orange)
            }
        }
    }

    /// عنوان زر الاختبار حسب الحالة
    private var testNotificationTitle: String {
        switch testNotificationState {
        case .idle:
            return tr("تنبيه تجريبي", "Test Notification")
        case .sending:
            return tr("جاري الإرسال...", "Sending...")
        case .verified:
            return tr("✓ تم التحقق", "✓ Verified")
        case .failed:
            return tr("✗ فشل الإرسال", "✗ Failed")
        case .timeout:
            return tr("⚠️ لم يتم التأكيد", "⚠️ Not Confirmed")
        }
    }

    /// نص فرعي لزر الاختبار حسب الحالة
    private var testNotificationSubtitle: String {
        switch testNotificationState {
        case .idle:
            return tr("تحقق من عمل التنبيهات", "Verify notifications work")
        case .sending:
            return tr("انتظر ظهور التنبيه...", "Wait for notification...")
        case .verified:
            return tr("التنبيهات تعمل بشكل صحيح", "Notifications working correctly")
        case .failed(let error):
            return error
        case .timeout:
            return tr("قد تكون التنبيهات محظورة", "Notifications may be blocked")
        }
    }

    /// أيقونة الجانب الأيمن/الأيسر
    private var testNotificationTrailingIcon: some View {
        Group {
            switch testNotificationState {
            case .idle:
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue.opacity(0.6))
            case .sending:
                EmptyView()
            case .verified:
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
            case .failed, .timeout:
                Button {
                    // إعادة المحاولة
                    NotificationService.shared.resetTestNotificationState()
                    testNotificationState = .idle
                } label: {
                    Text(tr("إعادة", "Retry"))
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.orange))
                }
            }
        }
    }

    /// لون خلفية زر الاختبار
    private var testNotificationBackgroundColor: Color {
        switch testNotificationState {
        case .idle, .sending: return .blue
        case .verified: return .green
        case .failed: return .red
        case .timeout: return .orange
        }
    }

    /// هل زر الاختبار مفعل؟
    private var isTestButtonEnabled: Bool {
        if case .idle = testNotificationState { return true }
        return false
    }

    /// تحذير عند انتهاء المهلة
    private var testNotificationTimeoutWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.orange)

            Text(tr(
                "تحقق من إعدادات iOS: الإشعارات، عدم الإزعاج، وضع التركيز",
                "Check iOS Settings: Notifications, DND, Focus Mode"
            ))
            .font(.system(.caption2, design: .rounded))
            .foregroundColor(.secondary)

            Spacer()

            Button {
                openSystemSettings()
            } label: {
                Text(tr("الإعدادات", "Settings"))
                    .font(.system(.caption2, design: .rounded).bold())
                    .foregroundColor(.orange)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Test Notification Observer (V4)

    private func setupTestNotificationObserver() {
        // مراقبة تغيرات حالة الإشعار التجريبي
        NotificationService.shared.onTestNotificationVerified = { [self] in
            withAnimation(.spring(response: 0.3)) {
                testNotificationState = .verified
                HapticManager.shared.notification(.success)
            }
        }

        // تحديث الحالة الأولية
        testNotificationState = NotificationService.shared.testNotificationState

        // مراقبة التغييرات عبر Combine (للحالات الأخرى)
        // ملاحظة: نستخدم Timer بسيط لتحديث الحالة بشكل دوري أثناء عرض الشاشة
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            let currentState = NotificationService.shared.testNotificationState
            if !areStatesEqual(testNotificationState, currentState) {
                withAnimation(.spring(response: 0.3)) {
                    testNotificationState = currentState
                }
            }
            // إيقاف المؤقت إذا لم تعد الشاشة معروضة (سيتم التعامل معه في onDisappear)
        }
    }

    /// مقارنة حالتين (لأن enum مع associated value لا يدعم Equatable تلقائياً)
    private func areStatesEqual(
        _ lhs: NotificationService.TestNotificationState,
        _ rhs: NotificationService.TestNotificationState
    ) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.sending, .sending): return true
        case (.verified, .verified): return true
        case (.timeout, .timeout): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }

    // MARK: - Advanced Row Helpers

    private func advancedRow<Content: View>(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }

            Spacer()

            content()
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func advancedToggleRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        advancedRow(icon: icon, iconColor: iconColor, title: title, subtitle: subtitle) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(ShiftTheme.ColorToken.brandPrimary)
        }
    }

    // MARK: - Save & Rebuild Helper

    private func saveAndRebuild() {
        NotificationConfigStore.shared.save(advancedConfig)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let context = UserShift.shared.shiftContext {
                let overrides = UserShift.shared.allManualOverrides
                NotificationService.shared.rebuildShiftNotifications(
                    context: context,
                    manualOverrides: overrides
                )
            }
            // V3: Reload scheduled notifications after rebuild
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                loadScheduledNotifications()
            }
        }
    }

    // MARK: - Load Scheduled Notifications (V3)

    private func loadScheduledNotifications() {
        NotificationService.shared.getPendingNotificationsCount { count in
            scheduledCount = count
        }
        NotificationService.shared.getUpcomingNotifications { notifications in
            upcomingNotifications = notifications
        }
    }

    // MARK: - Scheduled Notifications Preview (V3)

    private var scheduledNotificationsPreview: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(tr("التنبيهات المجدولة", "Scheduled Notifications"))
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundColor(.primary)

                Spacer()

                Text("\(scheduledCount)")
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(ShiftTheme.ColorToken.brandPrimary))
            }

            // Upcoming notifications list
            if !upcomingNotifications.isEmpty {
                VStack(spacing: 8) {
                    ForEach(upcomingNotifications, id: \.date) { notification in
                        HStack(spacing: 10) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.green)

                            Text(formatNotificationDate(notification.date))
                                .font(.system(.caption, design: .rounded))
                                .foregroundColor(.secondary)

                            Spacer()

                            Text(cleanTitle(notification.title))
                                .font(.system(.caption, design: .rounded).bold())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(14)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
    }

    private func formatNotificationDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        // Phase 2: Use Latin digits locale for consistent number display
        formatter.locale = settings.language == .arabic
            ? Locale(identifier: "ar_SA@numbers=latn")
            : Locale(identifier: "en_US_POSIX")

        let calendar = Calendar.current
        // Phase 2: Use 24-hour format (HH:mm) instead of 12-hour (h:mm a)
        if calendar.isDateInToday(date) {
            formatter.dateFormat = settings.language == .arabic ? "اليوم HH:mm" : "Today HH:mm"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = settings.language == .arabic ? "غداً HH:mm" : "Tomorrow HH:mm"
        } else {
            formatter.dateFormat = "E HH:mm"
        }

        return formatter.string(from: date)
    }

    private func cleanTitle(_ title: String) -> String {
        // Remove directional marks
        title.replacingOccurrences(of: "\u{200F}", with: "")
            .replacingOccurrences(of: "\u{200E}", with: "")
    }

    // MARK: - iOS Limitations Disclaimer (V4)

    private var iosLimitationsDisclaimer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)

                Text(tr("ملاحظة هامة", "Important"))
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundColor(.primary)
            }

            Text(tr(
                "قد لا تصل بعض التنبيهات بسبب قيود نظام iOS، مثل: وضع عدم الإزعاج، أوضاع التركيز، وضع توفير الطاقة، أو إذا كان التطبيق مغلقاً لفترة طويلة.",
                "Some notifications may not be delivered due to iOS restrictions, such as: Do Not Disturb, Focus modes, Low Power Mode, or if the app hasn't been opened recently."
            ))
            .font(.system(.caption, design: .rounded))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            Text(tr(
                "استخدم زر \"التنبيه التجريبي\" للتحقق من عمل التنبيهات على جهازك.",
                "Use the \"Test Notification\" button to verify notifications work on your device."
            ))
            .font(.system(.caption, design: .rounded))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
    }

    // MARK: - Permission Warning Banner (V2)

    private var permissionWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(tr("التنبيهات معطلة", "Notifications Disabled"))
                    .font(.system(.subheadline, design: .rounded).bold())
                    .foregroundColor(.primary)

                Text(tr(
                    "يرجى تفعيل التنبيهات من إعدادات النظام",
                    "Please enable notifications in System Settings"
                ))
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                openSystemSettings()
            } label: {
                Text(tr("فتح", "Open"))
                    .font(.system(.caption, design: .rounded).bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
    }

    // MARK: - Permission Helpers (V2)

    private func checkPermissionStatus() {
        NotificationService.shared.checkPermissionStatus { status in
            withAnimation {
                permissionStatus = status
            }
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ShiftTheme.ColorToken.brandWarning.opacity(colorScheme == .dark ? 0.15 : 0.12))
                    .frame(width: 64, height: 64)

                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(ShiftTheme.ColorToken.brandWarning)
            }

            Text(tr("اختر مستوى التنبيهات", "Choose Alert Level"))
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Info Note

    private var infoNote: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary.opacity(0.6))

                Text(tr(
                    "التنبيهات تصلك قبل 30 دقيقة من موعد البصمة.",
                    "Alerts arrive 30 minutes before punch time."
                ))
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
            }

            // V3: Discoverability hint for advanced settings
            if showAdvancedSection && !showAdvancedSettings {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10))
                        .foregroundColor(ShiftTheme.ColorToken.brandPrimary.opacity(0.8))

                    Text(tr(
                        "اضغط على \"إعدادات متقدمة\" للتخصيص",
                        "Tap \"Advanced Settings\" to customize"
                    ))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundColor(ShiftTheme.ColorToken.brandPrimary.opacity(0.8))
                }
            }
        }
        .padding(14)
        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
    }

    // MARK: - Apply Preset

    private func applyPreset(_ preset: NotificationPreset) {
        // Update the main toggle
        settings.notificationsEnabled = preset != .off

        // V3: Apply preset using the unified config (Single Source of Truth)
        NotificationConfigStore.shared.applyPreset(preset)

        // Update local state to reflect the new preset
        advancedConfig = NotificationConfigStore.shared.load()

        // Rebuild notifications
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let context = UserShift.shared.shiftContext {
                let overrides = UserShift.shared.allManualOverrides
                NotificationService.shared.rebuildShiftNotifications(
                    context: context,
                    manualOverrides: overrides
                )
            }
        }
    }
}

// MARK: - Notification Preset

enum NotificationPreset: String, CaseIterable {
    case off
    case essential
    case all

    var title: String {
        let isArabic = UserSettingsStore.shared.language == .arabic
        switch self {
        case .off: return isArabic ? "إيقاف" : "Off"
        case .essential: return isArabic ? "أساسي" : "Essential"
        case .all: return isArabic ? "الكل" : "All"
        }
    }

    var subtitle: String {
        let isArabic = UserSettingsStore.shared.language == .arabic
        switch self {
        case .off:
            return isArabic ? "لا تنبيهات" : "No alerts"
        case .essential:
            return isArabic ? "تنبيه بصمة الدخول فقط" : "Punch-in reminder only"
        case .all:
            return isArabic ? "الدخول + الخروج + التواجد" : "Punch-in + out + presence"
        }
    }

    var icon: String {
        switch self {
        case .off: return "bell.slash.fill"
        case .essential: return "bell.fill"
        case .all: return "bell.badge.fill"
        }
    }

    var color: Color {
        switch self {
        case .off: return .secondary
        case .essential: return ShiftTheme.ColorToken.brandPrimary
        case .all: return ShiftTheme.ColorToken.brandWarning
        }
    }
}

// MARK: - Preset Card

private struct PresetCard: View {
    let preset: NotificationPreset
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(preset.color.opacity(colorScheme == .dark ? 0.18 : 0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: preset.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(preset.color)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Text(preset.subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? preset.color : Color.secondary.opacity(0.3),
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(preset.color)
                            .frame(width: 14, height: 14)
                    }
                }
            }
            .padding(18)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        isSelected ? preset.color.opacity(0.4) : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
