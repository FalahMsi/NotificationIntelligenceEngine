import SwiftUI
import Combine

@main
struct DuamiApp: App {

    // MARK: - App State
    /// المصدر الحقيقي الوحيد (Single Source of Truth) لإعدادات التطبيق
    @StateObject private var settingsStore = UserSettingsStore.shared

    // Phase 4: Scene phase for timezone detection (Government-Grade Hardening)
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Scene Composition
    var body: some Scene {
        WindowGroup {
            RootContainerView()
                // حقن الإعدادات في البيئة لتصل لكل الشاشات
                .environmentObject(settingsStore)

                // 1️⃣ التحكم الديناميكي في اتجاه الواجهة (RTL / LTR)
                // ⚠️ هذا هو المكان الوحيد المسموح فيه ضبط الاتجاه
                .environment(
                    \.layoutDirection,
                    settingsStore.language == .arabic
                        ? .rightToLeft
                        : .leftToRight
                )

                // 2️⃣ ضبط اللغة للأرقام والتواريخ (Phase 2: استخدام Latin digits دائماً)
                .environment(
                    \.locale,
                    settingsStore.language == .arabic
                        ? Locale(identifier: "ar_SA@numbers=latn")
                        : Locale(identifier: "en_US_POSIX")
                )

                // 3️⃣ إجبار إعادة بناء الواجهة عند تغيير اللغة
                // (مهم جداً لمنع بقايا LTR)
                .id(settingsStore.language)

                // 4️⃣ التحكم في المظهر (نهاري / ليلي / تلقائي)
                .preferredColorScheme(resolvedColorScheme)

                // 5️⃣ اللون الأساسي للتطبيق (Global Tint)
                .tint(ShiftTheme.ColorToken.brandPrimary)

                // 6️⃣ تشغيل خدمات التمهيد عند الإقلاع
                .task {
                    AppBootstrap.shared.run()
                }

                // 7️⃣ نعومة الحركة عند تغيير الإعدادات
                .animation(.easeInOut, value: settingsStore.appearanceMode)

                // 8️⃣ Phase 4: Timezone change detection on foreground resume
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active {
                        handleForegroundResume()
                    }
                }
        }
    }

    // MARK: - Phase 4: Timezone Detection (Government-Grade Hardening)

    /// التعامل مع عودة التطبيق للمقدمة
    private func handleForegroundResume() {
        // التحقق من Feature Flag
        guard FeatureFlags.TIMEZONE_AUTO_REBUILD else {
            return
        }

        guard let change = TimezoneMonitor.shared.checkForTimezoneChange() else {
            return // لم يتغير شيء
        }

        // تسجيل التغيير في Activity Log
        MessagesStore.shared.add(
            kind: .timezoneChanged(oldTimezone: change.oldTimezone.identifier, newTimezone: change.newTimezone.identifier),
            sourceType: .system,
            sourceID: nil
        )

        // إعادة بناء التنبيهات إذا كان الإعداد مكتملاً
        guard settingsStore.isSetupComplete,
              let context = settingsStore.shiftContext else {
            return
        }

        // استخدام Actor إذا كان متاحاً
        if FeatureFlags.USE_NOTIFICATION_ACTOR {
            Task {
                await NotificationServiceActor.shared.scheduleNotifications(
                    context: context,
                    overrides: UserShift.shared.allManualOverrides
                )
            }
        } else {
            NotificationService.shared.rebuildShiftNotifications(
                context: context,
                manualOverrides: UserShift.shared.allManualOverrides
            )
        }
    }

    // MARK: - Helpers

    /// تحويل إعداد المظهر إلى ColorScheme
    private var resolvedColorScheme: ColorScheme? {
        switch settingsStore.appearanceMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}
