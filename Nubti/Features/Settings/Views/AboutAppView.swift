import SwiftUI

struct AboutAppView: View {
    
    // MARK: - Environment
    @EnvironmentObject private var settings: UserSettingsStore
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - App Info
    private let appName: String =
    Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Nubti"
    
    private let version: String = {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }()
    
    // MARK: - Constants
    private let privacyURL = URL(string: "https://falahmsi.github.io/duami-privacy/")!
    private let contactEmail = "Info.alharbi94@gmail.com"
    private let telegramURL = URL(string: "https://t.me/kenetvv")!
    private let creatorName = ("فلاح الخشمان", "Falah Al-Khashman")
    
    // MARK: - Helpers
    private var isArabic: Bool {
        settings.language == .arabic
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            ShiftTheme.appBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    
                    headerSection
                    
                    infoSections
                    
                    footerSection
                }
                .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                .padding(.bottom, 60)
            }
        }
        .environment(\.layoutDirection, settings.language.direction)
        .navigationTitle(tr("حول التطبيق", "About App"))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        ShiftTheme.ColorToken.brandPrimary.opacity(
                            colorScheme == .dark ? 0.15 : 0.12
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ShiftTheme.ColorToken.brandPrimary,
                                ShiftTheme.ColorToken.brandInfo
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "calendar")
                    .font(.system(size: 44, weight: .black))
                    .foregroundColor(.white)
            }
            
            VStack(spacing: 8) {
                Text(tr("نوبتي", "Nubti"))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                
                Text("\(tr("الإصدار", "Version")) \(version)")
                    .font(.system(.subheadline, design: .rounded))
                    .bold()
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
        .padding(.top, 40)
    }
    
    // MARK: - Sections
    private var infoSections: some View {
        VStack(spacing: 20) {
            
            infoCard(
                title: tr("عن التطبيق", "About"),
                icon: "text.alignright",
                color: ShiftTheme.ColorToken.brandPrimary
            ) {
                VStack(alignment: isArabic ? .trailing : .leading, spacing: 12) {
                    Text(
                        tr(
                            "نوبتي - تطبيق شخصي لتنظيم مواعيد الدوام وتتبع الإجازات والاستئذانات",
                            "Nubti - A personal app for organizing shift schedules and tracking leaves and permissions."
                        )
                    )
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(isArabic ? .trailing : .leading)

                    // Creator attribution
                    HStack(spacing: 6) {
                        Text(tr("تصميم وتطوير:", "Designed & built by:"))
                            .foregroundColor(.secondary)
                        Text(tr(creatorName.0, creatorName.1))
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    .font(.system(.caption, design: .rounded))
                }
            }
            
            infoCard(
                title: tr("الخصوصية والأمان", "Privacy & Security"),
                icon: "shield.checkered",
                color: ShiftTheme.ColorToken.brandSuccess
            ) {
                VStack(
                    alignment: isArabic ? .trailing : .leading,
                    spacing: 14
                ) {
                    Text(
                        tr(
                            "يتم تخزين جميع البيانات محلياً على جهازك لضمان الخصوصية.",
                            "All data is stored locally on your device for full privacy."
                        )
                    )
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    
                    Button {
                        openURL(privacyURL)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "link")
                            Text(tr("سياسة الخصوصية", "Privacy Policy"))
                        }
                        .font(.system(.caption, design: .rounded).bold())
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(
                            ShiftTheme.ColorToken.brandSuccess.opacity(0.12)
                        )
                        .cornerRadius(10)
                    }
                }
            }
            
            infoCard(
                title: tr("تواصل معنا", "Contact"),
                icon: "message.fill",
                color: ShiftTheme.ColorToken.brandWarning
            ) {
                // ACTION BUTTONS — clear visual affordance
                HStack(spacing: 12) {
                    // Telegram Button
                    Button {
                        openURL(telegramURL)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Telegram")
                                .font(.system(.subheadline, design: .rounded).bold())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Email Button
                    Button {
                        if let url = URL(string: "mailto:\(contactEmail)") {
                            openURL(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Email")
                                .font(.system(.subheadline, design: .rounded).bold())
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }
    
    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 8) {
            Text(tr("صُنع بكل ❤️ في الكويت", "Made in Kuwait"))
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary.opacity(0.6))

            Text(tr("شكراً لاستخدامك | نوبتي", "Thank you for using | Nubti"))
                .font(.system(.caption2, design: .rounded))
                .foregroundColor(.secondary.opacity(0.5))
        }
    }
    
    // MARK: - Reusable Card
    private func infoCard<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(
            alignment: isArabic ? .trailing : .leading,
            spacing: 14
        ) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(
                        color.opacity(colorScheme == .dark ? 0.1 : 0.15)
                    )
                    .clipShape(Circle())
                
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.black)
                
                Spacer()
            }
            
            content()
                .frame(
                    maxWidth: .infinity,
                    alignment: isArabic ? .trailing : .leading
                )
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .contentShape(Rectangle())
    }
}
