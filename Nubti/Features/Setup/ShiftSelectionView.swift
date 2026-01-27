import SwiftUI

// MARK: - Environment Key for Onboarding Mode

/// مفتاح البيئة لتحديد هل نحن في وضع الإعداد الأولي
private struct IsOnboardingModeKey: EnvironmentKey {
    // القيمة الافتراضية true لأن معظم الاستخدامات ستكون في الـ onboarding
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var isOnboardingMode: Bool {
        get { self[IsOnboardingModeKey.self] }
        set { self[IsOnboardingModeKey.self] = newValue }
    }
}

/// ShiftSelectionView
/// صفحة إعداد النظام (كاملة – بدون Sheet).
/// تم التعديل: تحسين النصوص والمنطق للتوافق مع التبسيط الجديد.
struct ShiftSelectionView: View {

    @EnvironmentObject private var settings: UserSettingsStore
    @ObservedObject private var userShift = UserShift.shared
    @Environment(\.colorScheme) var colorScheme
    @State private var isSaving = false

    /// هل نحن في وضع الإعداد الأولي؟
    /// هذه القيمة تُحدد عند ظهور الـ View ولا تتغير حتى لو تغير isSetupComplete
    /// لمنع تغير الواجهة أثناء الانتقال
    @State private var isOnboardingMode: Bool = true
    
    var body: some View {
        VStack(spacing: 0) {

            // 1. محتوى اختيار نظام النوبات
            // التمرير مفعل دائماً لرؤية كل الخيارات
            ScrollView(showsIndicators: false) {
                shiftContent
            }
            .safeAreaInset(edge: .top) {
                // مسافة علوية للـ Safe Area
                Color.clear.frame(height: 0)
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
                
                // زر التخطي الثانوي
                Button {
                    HapticManager.shared.selection()
                    completeSetup()
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
        .navigationTitle(tr("إعداد الدوام", "Shift Setup"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.layoutDirection, settings.language.direction)
        .environment(\.isOnboardingMode, isOnboardingMode)
        .onAppear {
            // تحديد حالة الـ onboarding عند ظهور الـ View
            // هذه القيمة لا تتغير حتى لو تغير isSetupComplete لاحقاً
            isOnboardingMode = !settings.isSetupComplete
        }
    }
    
    // MARK: - Components

    private var shiftContent: some View {
        VStack(spacing: 24) {
            ShiftSelectionSheet()
                .environmentObject(userShift)

            // تنبيه الأنظمة الثابتة (للتوضيح فقط)
            if let context = userShift.shiftContext {
                let system = ShiftEngine.shared.system(for: context.systemID)
                if !system.supportsFlexSettings {
                    fixedSystemNote
                        .padding(.horizontal, 24)
                }
            }
        }
        .padding(.vertical, 20)
    }

    private var fixedSystemNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.blue)
            
            Text(tr("هذا النظام يتبع جدولاً ثابتاً، ولا يتأثر وقت الخروج بالاستئذانات.", "This system follows a fixed schedule; exit time is not affected by permissions."))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .cornerRadius(12)
    }
    
    // MARK: - Logic
    
    private func handleConfirmAction() {
        guard let context = userShift.shiftContext else { return }
        isSaving = true
        
        // محاكاة حفظ سريع
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            
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
            
            completeSetup()
            isSaving = false
        }
    }
    
    private func completeSetup() {
        // تأخير بسيط للتأكد من اكتمال الحفظ قبل الانتقال
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.3)) {
                settings.isSetupComplete = true
            }
        }
    }
}
