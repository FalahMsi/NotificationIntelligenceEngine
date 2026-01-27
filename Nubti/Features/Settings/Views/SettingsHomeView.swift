import SwiftUI

struct SettingsHomeView: View {
    @ObservedObject private var settings: UserSettingsStore
    @Environment(\.colorScheme) var colorScheme
    @State private var showResetAlert = false

    init(settings: UserSettingsStore) {
        self.settings = settings
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // MARK: - اللغة والمنطقة
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: tr("اللغة والمنطقة", "Language & Region"))
                        
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "globe")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.blue)
                                    .frame(width: 44, height: 44)
                                    .background(Color.blue.opacity(0.12))
                                    .cornerRadius(12)
                                
                                Text(tr("لغة التطبيق", "App Language"))
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            Picker("", selection: $settings.language) {
                                ForEach(AppLanguage.allCases, id: \.self) { lang in
                                    Text(lang.displayName).tag(lang)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                    
                    // MARK: - المظهر
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: tr("المظهر", "Appearance"))
                        
                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: settings.appearanceMode == .dark ? "moon.stars.fill" : "sun.max.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.orange)
                                    .frame(width: 44, height: 44)
                                    .background(Color.orange.opacity(0.12))
                                    .cornerRadius(12)
                                
                                Text(tr("نمط العرض", "Theme"))
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                            }
                            
                            Picker("", selection: $settings.appearanceMode) {
                                ForEach(AppearanceMode.allCases, id: \.self) { mode in
                                    Text(tr(mode.rawValue, translateAppearance(mode))).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                    
                    // MARK: - التخصيص
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: tr("تخصيص التجربة", "Customization"))
                        
                        settingNavigationLink(
                            destination: CalendarSettingsView().environmentObject(settings),
                            icon: "calendar",
                            color: ShiftTheme.ColorToken.brandSuccess,
                            title: tr("التقويم", "Calendar"),
                            subtitle: tr("ربط ومزامنة تقويم الجهاز", "Sync device calendar")
                        )
                    }
                    
                    // MARK: - عن التطبيق
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: tr("عن التطبيق", "About App"))

                        settingNavigationLink(
                            destination: AboutAppView(),
                            icon: "info.circle.fill",
                            color: .secondary,
                            title: tr("حول التطبيق", "About"),
                            subtitle: tr("معلومات الإصدار وسياسة الخصوصية", "Version info & Privacy Policy")
                        )
                    }

                    // MARK: - إعادة التعيين
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader(title: tr("خيارات متقدمة", "Advanced"))

                        Button {
                            HapticManager.shared.impact(.medium)
                            showResetAlert = true
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.red)
                                    .frame(width: 44, height: 44)
                                    .background(Color.red.opacity(0.12))
                                    .cornerRadius(12)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tr("إعادة تعيين التطبيق", "Reset App"))
                                        .font(.system(.headline, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundColor(.red)

                                    Text(tr("حذف جميع البيانات والبدء من جديد", "Delete all data and start fresh"))
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer().frame(height: 120)
                }
                .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                .padding(.top, 20)
            }
            .background(Color.clear)
            .navigationTitle(tr("الإعدادات", "Settings"))
            .navigationBarTitleDisplayMode(.large)
            .environment(\.layoutDirection, settings.language.direction)
            .alert(
                tr("إعادة تعيين التطبيق", "Reset App"),
                isPresented: $showResetAlert
            ) {
                Button(tr("إلغاء", "Cancel"), role: .cancel) { }
                Button(tr("إعادة تعيين", "Reset"), role: .destructive) {
                    performReset()
                }
            } message: {
                Text(tr(
                    "سيتم حذف جميع بياناتك وإعداداتك.\nستعود لصفحة الترحيب لإعادة إعداد التطبيق.\n\nهل أنت متأكد؟",
                    "All your data and settings will be deleted.\nYou will return to the welcome screen to set up the app again.\n\nAre you sure?"
                ))
            }
        }
    }

    // MARK: - Reset Logic

    private func performReset() {
        HapticManager.shared.notification(.warning)

        // 1. مسح بيانات UserShift (يشمل الإشعارات تلقائياً)
        UserShift.shared.reset()

        // 2. إعادة تعيين الإعدادات
        settings.isSetupComplete = false
        settings.systemType = nil
        settings.startPhase = nil
        settings.setupIndex = nil
        settings.shiftStartTime = nil
        settings.shiftEndTime = nil
        settings.referenceDate = nil
        settings.notificationsEnabled = false
        settings.systemCalendarIntegrationEnabled = false
        // نحتفظ باللغة والمظهر كما هي
    }
    
    // MARK: - Helper Components & Logic

    private func translateAppearance(_ mode: AppearanceMode) -> String {
        switch mode {
        case .system: return "Auto"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    
    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundColor(.secondary)
            .padding(.horizontal, 4)
    }
    
    private func settingNavigationLink<Destination: View>(
        destination: Destination,
        icon: String,
        color: Color,
        title: String,
        subtitle: String
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12))
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.secondary.opacity(colorScheme == .dark ? 0.4 : 0.7))
                    .flipsForRightToLeftLayoutDirection(true)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture().onEnded {
                HapticManager.shared.selection()
            }
        )
    }
}
