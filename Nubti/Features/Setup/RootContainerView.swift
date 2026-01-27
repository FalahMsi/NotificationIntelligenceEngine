import SwiftUI

/// RootContainerView
/// نقطة التحكم المركزية التي تدير التنقل.
/// تم التدقيق: تحسين الأداء ودعم كامل للترجمة القسرية (Override).
struct RootContainerView: View {
    
    @EnvironmentObject private var settings: UserSettingsStore
    
    // ✅ استخدام ObservedObject لأن UserShift هو Singleton مشترك
    @ObservedObject private var userShift = UserShift.shared
    
    @Environment(\.colorScheme) var systemColorScheme
    
    // MARK: - State Management
    @State private var currentPage: AppPage = .calendar
    @State private var showShiftSetupSheet: Bool = false
    @State private var isAppReady: Bool = false
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var introComplete: Bool = false

    // Phase 4: Reference Date Validation (Government-Grade Hardening)
    @State private var showVerificationWizard: Bool = false
    @ObservedObject private var verificationWizard = ShiftVerificationWizard.shared

    // MARK: - Custom Background
    private var appBackgroundColor: Color {
        let isDark = (settings.appearanceMode == .dark) || (settings.appearanceMode == .system && systemColorScheme == .dark)
        
        if isDark {
            return ShiftTheme.appBackground
        } else {
            return Color(red: 245/255, green: 246/255, blue: 250/255)
        }
    }

    var body: some View {
        ZStack {
            appBackgroundColor.ignoresSafeArea()

            if isAppReady {
                if settings.isSetupComplete {
                    mainApp
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.95)), removal: .opacity))
                } else {
                    setupFlow
                        .transition(.opacity)
                }
            } else {
                splashView
            }
        }
        .preferredColorScheme(getColorScheme())
        // ✅ إجبار اتجاه التخطيط للتطبيق بالكامل بناءً على إعدادات المستخدم
        .environment(\.layoutDirection, settings.language.direction)
        .ignoresSafeArea(.keyboard)
        .onAppear {
            prepareAppData()
        }
        // ✅ إعادة تعيين حالة الانترو عند إعادة تعيين التطبيق
        .onChange(of: settings.isSetupComplete) { _, isComplete in
            if !isComplete {
                // المستخدم عمل reset - نرجعه لصفحة الترحيب
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    introComplete = false
                    showShiftSetupSheet = false
                    currentPage = .calendar
                }
            }
        }
        // عرض Sheet إعداد الدوام (نفس الـ Sheet المستخدم في التطبيق الرئيسي)
        .sheet(isPresented: $showShiftSetupSheet) {
            OnboardingShiftSetupSheet(
                onComplete: {
                    showShiftSetupSheet = false
                    settings.isSetupComplete = true
                },
                onSkip: {
                    showShiftSetupSheet = false
                    settings.isSetupComplete = true
                }
            )
            .environmentObject(settings)
            .interactiveDismissDisabled() // منع الإغلاق بالسحب
        }
        // Phase 4: Verification Wizard Sheet (Government-Grade Recovery)
        .sheet(isPresented: $showVerificationWizard) {
            ShiftVerificationView()
                .environmentObject(settings)
                .interactiveDismissDisabled(true)
        }
        // Sync wizard presentation state
        .onChange(of: verificationWizard.isPresented) { _, isPresented in
            showVerificationWizard = isPresented
        }
        .onChange(of: showVerificationWizard) { _, isShowing in
            if !isShowing && verificationWizard.isPresented {
                verificationWizard.isPresented = false
            }
        }
    }

    // MARK: - Helper Functions

    /// تحديد نمط العرض بناءً على اختيار المستخدم
    /// - `.light`: دايماً نهاري
    /// - `.dark`: دايماً ليلي
    /// - `.system`: تلقائي حسب الوقت (6 صباحاً = نهاري، 6 مساءً = ليلي)
    private func getColorScheme() -> ColorScheme? {
        switch settings.appearanceMode {
        case .light: return .light
        case .dark: return .dark
        case .system:
            // التحويل التلقائي حسب الوقت
            let hour = Calendar.current.component(.hour, from: Date())
            // من 6 صباحاً إلى 6 مساءً = نهاري، غير ذلك = ليلي
            let isDaytime = hour >= 6 && hour < 18
            return isDaytime ? .light : .dark
        }
    }

    private func prepareAppData() {
        Task {
            AppBootstrap.shared.run()

            // تحريك اللوجو
            withAnimation(.easeOut(duration: 0.8)) {
                logoScale = 1.0
                logoOpacity = 1.0
            }

            // الانتقال للشاشة التالية
            try? await Task.sleep(nanoseconds: 600_000_000)

            await MainActor.run {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isAppReady = true
                }

                // Phase 4: Validate reference date after app is ready (Government-Grade Hardening)
                // Only validate if setup is complete (user has configured a shift)
                if settings.isSetupComplete {
                    performReferenceDateValidation()
                }
            }
        }
    }

    // MARK: - Phase 4: Reference Date Validation (Government-Grade Hardening)

    /// Validates the reference date and triggers recovery wizard if needed
    private func performReferenceDateValidation() {
        let validationResult = userShift.validateReferenceDate()

        guard !validationResult.isValid else {
            // Data is valid - no action needed
            return
        }

        // Log the corruption detection
        MessagesStore.shared.add(
            kind: .referenceDateCorruptionDetected(reason: validationResult.localizedDescription),
            sourceType: .validation,
            sourceID: nil
        )

        // Try automatic backup recovery first
        if validationResult == .checksumMismatch || validationResult == .backupMismatch {
            if userShift.attemptBackupRecovery() {
                // Recovery successful - log and continue
                MessagesStore.shared.add(
                    kind: .referenceDateRecovered(method: "backup"),
                    sourceType: .validation,
                    sourceID: nil
                )
                return
            }
        }

        // Backup recovery failed or not applicable - show wizard
        let availablePhases = userShift.availablePhasesForWizard()
        if !availablePhases.isEmpty {
            verificationWizard.startVerification(
                reason: validationResult,
                availablePhases: availablePhases
            )
        } else {
            // No phases available - log reset required
            MessagesStore.shared.add(
                kind: .referenceDateResetRequired,
                sourceType: .validation,
                sourceID: nil
            )
        }
    }
    
    // MARK: - Views
    private var splashView: some View {
        VStack(spacing: ShiftTheme.Spacing.md) {
            Image("Asset")
                .resizable()
                .scaledToFit()
                .frame(width: 90, height: 90)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
            
            Text(tr("نوبتي", "Nubti"))
                .font(.system(.headline, design: .rounded))
                .foregroundColor(.primary)
                .opacity(logoOpacity)
        }
    }
    
    private var setupFlow: some View {
        // صفحات الانترو فقط - بدون صفحة إعدادات منفصلة
        OnboardingIntroView(goToShiftSetup: $showShiftSetupSheet)
    }
    
    // MARK: - Main App Layout
    private var mainApp: some View {
        ZStack(alignment: .bottom) {
            
            // 1. المحتوى الرئيسي
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, ShiftTheme.Layout.bottomContentPadding)
            
            // 2. شريط التنقل السفلي
            BottomBarView(
                selectedPage: currentPage,
                onSelect: handlePageSelection
            )
            .transition(.move(edge: .bottom))
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        switch currentPage {
        case .calendar:
            CalendarView(settings: settings)
        case .updates:
            UpdatesView()
        case .leaves:
            ManualLeavesRootView()
        case .services:
            ServicesHubView()
        case .settings:
            SettingsHomeView(settings: settings)
        case .shiftSelection:
            ShiftSelectionView()
        }
    }
    
    private func handlePageSelection(_ page: AppPage) {
        guard settings.isSetupComplete else { return }
        HapticManager.shared.impact(.light)

        // If already on calendar and tapping calendar again, trigger scroll to today
        if page == .calendar && currentPage == .calendar {
            NotificationCenter.default.post(name: .scrollCalendarToToday, object: nil)
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentPage = page
        }
    }
}

// MARK: - Notification Name Extension
extension Notification.Name {
    static let scrollCalendarToToday = Notification.Name("scrollCalendarToToday")
}

// MARK: - Onboarding Shift Setup Sheet
/// Sheet إعداد الدوام للمستخدمين الجدد
/// يستخدم نفس ShiftSelectionSheet الموجود في التطبيق مع أزرار مخصصة للـ Onboarding
struct OnboardingShiftSetupSheet: View {

    @EnvironmentObject private var settings: UserSettingsStore
    @ObservedObject private var userShift = UserShift.shared
    @Environment(\.colorScheme) var colorScheme

    let onComplete: () -> Void
    let onSkip: () -> Void

    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. محتوى إعداد الدوام
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text(tr("إعداد الدوام", "Shift Setup"))
                                .font(.system(size: 28, weight: .black, design: .rounded))

                            Text(tr(
                                "اختر نظام دوامك وحدد حالتك في يوم معين",
                                "Choose your shift system and set your status for a specific date"
                            ))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)

                        // محتوى الإعدادات (بدون header و save button - يوفرها هذا الـ View)
                        ShiftSelectionSheet(showControls: false)
                            .environmentObject(userShift)
                    }
                    .padding(.vertical, 20)
                }

                // 2. منطقة الأزرار السفلية
                VStack(spacing: 16) {
                    // زر التأكيد الرئيسي
                    Button {
                        handleConfirmAction()
                    } label: {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text(tr("حفظ الإعدادات", "Save Settings"))
                                    .font(.system(.headline, design: .rounded))
                                    .fontWeight(.bold)

                                Image(systemName: "checkmark.circle.fill")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            Group {
                                if userShift.shiftContext != nil {
                                    LinearGradient(
                                        colors: [ShiftTheme.ColorToken.brandPrimary, ShiftTheme.ColorToken.brandInfo],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                } else {
                                    Color.gray.opacity(colorScheme == .dark ? 0.3 : 0.2)
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(
                            color: (userShift.shiftContext != nil) ? ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.4 : 0.2) : Color.clear,
                            radius: 10, x: 0, y: 5
                        )
                    }
                    .disabled(userShift.shiftContext == nil || isSaving)

                    // زر التخطي
                    Button {
                        HapticManager.shared.selection()
                        onSkip()
                    } label: {
                        Text(tr("تخطي الإعداد", "Skip Setup"))
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 30)
                .background(
                    ZStack {
                        Rectangle().fill(.ultraThinMaterial)
                        VStack {
                            Rectangle()
                                .frame(height: 0.5)
                                .foregroundColor(Color.primary.opacity(0.1))
                            Spacer()
                        }
                    }
                    .ignoresSafeArea(edges: .bottom)
                )
            }
            .background(ShiftTheme.appBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.layoutDirection, settings.language.direction)
        }
    }

    // MARK: - Logic

    private func handleConfirmAction() {
        guard let context = userShift.shiftContext else { return }
        isSaving = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // تحويل SystemID إلى النوع المستخدم في الإعدادات
            let uiSystemType: ShiftSystemType
            switch context.systemID {
            case .threeShiftTwoOff:     uiSystemType = .threeShiftTwoOff
            case .twentyFourFortyEight: uiSystemType = .twentyFourFortyEight
            case .twoWorkFourOff:       uiSystemType = .twoWorkFourOff
            case .standardMorning:      uiSystemType = .standardMorning
            case .eightHourShift:       uiSystemType = .eightHourShift
            }

            settings.systemType = uiSystemType
            settings.startPhase = context.startPhase
            settings.setupIndex = context.setupIndex
            settings.shiftStartTime = context.shiftStartTime
            settings.referenceDate = context.referenceDate

            HapticManager.shared.notification(.success)

            // إعادة بناء التنبيهات
            NotificationService.shared.rebuildShiftNotifications(
                context: context,
                manualOverrides: userShift.allManualOverrides
            )

            isSaving = false
            onComplete()
        }
    }
}
