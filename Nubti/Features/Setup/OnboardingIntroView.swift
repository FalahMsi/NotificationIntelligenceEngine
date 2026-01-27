import SwiftUI

/// OnboardingIntroView
/// شاشات الترحيب: صفحة اللغة + 3 صفحات انترو - للعرض فقط
/// بعد الانتهاء، ينتقل المستخدم لصفحة إعداد الدوام
struct OnboardingIntroView: View {

    @EnvironmentObject private var settings: UserSettingsStore
    @Binding var goToShiftSetup: Bool
    @Environment(\.colorScheme) var colorScheme

    @State private var showIntroPages = false
    @State private var currentPage: Int = 0
    @State private var appear = false
    @State private var languageAppear = false

    private let totalPages = 3

    var body: some View {
        ZStack {
            // الخلفية
            ShiftTheme.appBackground.ignoresSafeArea()

            // تأثير التوهج الخلفي
            Circle()
                .fill(ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.12 : 0.06))
                .frame(width: 350, height: 350)
                .blur(radius: 120)
                .offset(y: -180)
                .allowsHitTesting(false)

            if showIntroPages {
                // صفحات الانترو الثلاث
                introContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                // صفحة اختيار اللغة
                languageSelectionPage
                    .transition(.opacity)
            }
        }
        .environment(\.layoutDirection, settings.language.direction)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showIntroPages)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                languageAppear = true
            }
        }
    }

    // MARK: - صفحة اختيار اللغة

    private var languageSelectionPage: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.height < 700
            let logoSize: CGFloat = isCompact ? 100 : 120
            let glowSize: CGFloat = isCompact ? 130 : 150

            VStack(spacing: isCompact ? 24 : 32) {
                Spacer()

                // اللوغو مع تأثير حركي
                ZStack {
                    // توهج خلفي متحرك
                    Circle()
                        .fill(ShiftTheme.ColorToken.brandPrimary.opacity(0.15))
                        .frame(width: glowSize, height: glowSize)
                        .blur(radius: 30)
                        .scaleEffect(languageAppear ? 1.1 : 0.9)

                    // اللوغو الرئيسي
                    Image("Asset")
                        .resizable()
                        .scaledToFit()
                        .frame(width: logoSize, height: logoSize)
                        .shadow(color: ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.5 : 0.3), radius: 20, y: 10)
                }
                .scaleEffect(languageAppear ? 1 : 0.5)
                .opacity(languageAppear ? 1 : 0)

                // اسم التطبيق
                VStack(spacing: 4) {
                    Text("نوبتي")
                        .font(.system(size: isCompact ? 32 : 38, weight: .black, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Nubti")
                        .font(.system(size: isCompact ? 18 : 22, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .opacity(languageAppear ? 1 : 0)
                .offset(y: languageAppear ? 0 : 20)

                Spacer()

                // اختيار اللغة
                VStack(spacing: 12) {
                    Text("اختر لغتك • Choose Language")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        // زر العربية
                        languageButton(
                            title: "العربية",
                            isSelected: settings.language == .arabic,
                            isCompact: isCompact
                        ) {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.3)) {
                                settings.language = .arabic
                            }
                        }

                        // زر الإنجليزية
                        languageButton(
                            title: "English",
                            isSelected: settings.language == .english,
                            isCompact: isCompact
                        ) {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.3)) {
                                settings.language = .english
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .opacity(languageAppear ? 1 : 0)
                .offset(y: languageAppear ? 0 : 20)

                Spacer()

                // زر ابدأ
                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.impact(.medium)
                        appear = false
                        withAnimation {
                            showIntroPages = true
                        }
                        // تفعيل الأنميشن للصفحات الجديدة
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeOut(duration: 0.8)) {
                                appear = true
                            }
                        }
                    } label: {
                        HStack {
                            Text(tr("ابدأ", "Start"))
                                .font(.system(size: isCompact ? 15 : 17, weight: .bold, design: .rounded))

                            Image(systemName: "arrow.right")
                                .font(.system(size: isCompact ? 15 : 17, weight: .bold))
                                .flipsForRightToLeftLayoutDirection(true)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: isCompact ? 48 : 54)
                        .background(
                            LinearGradient(
                                colors: [ShiftTheme.ColorToken.brandPrimary, ShiftTheme.ColorToken.brandInfo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.4 : 0.25), radius: 8, x: 0, y: 4)
                    }

                    // زر التخطي
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            goToShiftSetup = true
                        }
                    } label: {
                        Text(tr("تخطي", "Skip"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 6)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, isCompact ? 24 : 36)
                .opacity(languageAppear ? 1 : 0)
                .offset(y: languageAppear ? 0 : 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func languageButton(title: String, isSelected: Bool, isCompact: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: isCompact ? 14 : 15, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: isCompact ? 40 : 44)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                colors: [ShiftTheme.ColorToken.brandPrimary, ShiftTheme.ColorToken.brandInfo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            Color.clear
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }

    // MARK: - محتوى الانترو

    private var introContent: some View {
        VStack(spacing: 0) {
            // المحتوى الرئيسي
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                featuresPage.tag(1)
                developerPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // مؤشر الصفحات
            pageIndicator
                .padding(.bottom, 24)

            // منطقة الأزرار
            buttonsArea
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
    }

    // MARK: - Page 1: الترحيب

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()

            // اللوغو مع تأثير حركي
            ZStack {
                // توهج خلفي متحرك
                Circle()
                    .fill(ShiftTheme.ColorToken.brandPrimary.opacity(0.15))
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)
                    .scaleEffect(appear ? 1.1 : 0.9)

                // اللوغو الرئيسي
                Image("Asset")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .shadow(color: ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.5 : 0.3), radius: 20, y: 10)
            }
            .scaleEffect(appear ? 1 : 0.6)
            .opacity(appear ? 1 : 0)

            // النص
            VStack(spacing: 16) {
                Text(tr("أهلاً فيك 👋", "Welcome 👋"))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                Text(tr(
                    "نوبتي يساعدك تنظم دوامك ونوباتك وتدوين انجازاتك بكل سهولة \nبدون تعقيد، بدون حسابات، وبدون إنترنت \nكل شي واضح قدامك ",
                    "Nubti helps you organize your shifts easily \nNo complexity, no calculations, no internet.\nEverything is clear in front of you "
                ))
                .font(.system(.body, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.horizontal, 24)
            }
            .offset(y: appear ? 0 : 20)
            .opacity(appear ? 1 : 0)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 2: المميزات

    private var featuresPage: some View {
        VStack(spacing: 32) {
            Spacer()

            // العنوان
            Text(tr("كل شي في مكان واحد", "Everything in one place"))
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)

            // المميزات
            VStack(spacing: 20) {
                featureRow(
                    icon: "bell",
                    text: tr("تنبيهات قبل الدوام - يعني ما راح تنسى", "Reminders before shift - never forget")
                )

                featureRow(
                    icon: "calendar",
                    text: tr("جدولك واضح - تعرف متى تداوم ومتى ترتاح", "Clear schedule - know work vs rest days")
                )

                featureRow(
                    icon: "doc.text",
                    text: tr("تقارير جاهزة - لو احتجتها", "Ready reports - when you need them")
                )

                featureRow(
                    icon: "icloud.slash",
                    text: tr("يشتغل بدون نت - دايم وياك وين ماكنت", "Works offline - always with you")
                )
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .regular))
                .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                .frame(width: 44, height: 44)
                .background(ShiftTheme.ColorToken.brandPrimary.opacity(0.1))
                .clipShape(Circle())

            Text(text)
                .font(.system(.subheadline, design: .rounded))
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)

            Spacer()
        }
    }

    // MARK: - Page 3: المطور

    private var developerPage: some View {
        VStack(spacing: 32) {
            Spacer()

            // اللوغو الصغير
            ZStack {
                Circle()
                    .fill(ShiftTheme.ColorToken.brandPrimary.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .blur(radius: 15)

                Image("Asset")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70, height: 70)
                    .shadow(color: ShiftTheme.ColorToken.brandPrimary.opacity(0.2), radius: 10, y: 5)
            }

            // النص
            VStack(spacing: 20) {
                Text(tr("شنو قصة نوبتي؟", "The Story of Nubti"))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                VStack(spacing: 12) {
                    Text(tr(
                        "أنا أخوكم فلاح الخشمان، مساعد مهندس",
                        "I'm Falah Al-Khashman, an engineering assistant."
                    ))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                    Text(tr(
                        "بنيت نوبتي من تجربتي الشخصية مع الدوام والنوبات وتدوين الملاحظات اليومية والانجازات\nكنت أحتاج شي بسيط يساعدني أنظم وقتي، فسويته",
                        "I built Nubti from my personal experience with shifts \nI needed something simple to organize my time & writing notes - so I made it"
                    ))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                    Text(tr(
                        "أتمنى يفيدكم مثل ما فادني\nولا تنسوني من صالح دعائكم 🤲",
                        "I hope it helps you as it helped me \nKeep me in your prayers 🤲"
                    ))
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 24)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - مؤشر الصفحات

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? ShiftTheme.ColorToken.brandPrimary : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPage ? 1.2 : 1)
                    .animation(.spring(response: 0.3), value: currentPage)
            }
        }
    }

    // MARK: - الأزرار

    private var buttonsArea: some View {
        VStack(spacing: 16) {
            // صف الأزرار الرئيسية (السابق + التالي)
            HStack(spacing: 12) {
                // زر السابق (يظهر فقط إذا لم نكن في الصفحة الأولى)
                if currentPage > 0 {
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentPage -= 1
                        }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.left")
                                .font(.headline.bold())
                                .flipsForRightToLeftLayoutDirection(true)

                            Text(tr("السابق", "Back"))
                                .font(.headline.bold())
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    }
                }

                // زر التالي الرئيسي
                Button {
                    HapticManager.shared.impact(.medium)
                    if currentPage < totalPages - 1 {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            currentPage += 1
                        }
                    } else {
                        // الصفحة الأخيرة - انتقل لإعداد الدوام
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            goToShiftSetup = true
                        }
                    }
                } label: {
                    HStack {
                        Text(currentPage < totalPages - 1
                            ? tr("التالي", "Next")
                            : tr("ابدأ استخدام نوبتي", "Start Using Nubti")
                        )
                        .font(.headline.bold())

                        if currentPage < totalPages - 1 {
                            Image(systemName: "arrow.right")
                                .font(.headline.bold())
                                .flipsForRightToLeftLayoutDirection(true)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [ShiftTheme.ColorToken.brandPrimary, ShiftTheme.ColorToken.brandInfo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.4 : 0.25), radius: 10, x: 0, y: 5)
                }
            }

            // زر التخطي
            Button {
                HapticManager.shared.selection()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    goToShiftSetup = true
                }
            } label: {
                Text(tr("تخطي", "Skip"))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
        .opacity(appear ? 1 : 0)
        .offset(y: appear ? 0 : 20)
    }
}
