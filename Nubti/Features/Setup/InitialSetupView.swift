import SwiftUI

/// InitialSetupView
/// شاشة الترحيب الأولى - الانطباع الأول (تدعم اللغتين والوضعين)
/// تم التعديل: تصحيح محاذاة النصوص والاتجاهات لدعم RTL بشكل احترافي.
struct InitialSetupView: View {

    @EnvironmentObject private var settings: UserSettingsStore
    @Binding var selection: Int
    @Environment(\.colorScheme) var colorScheme
    @State private var appear = false

    var body: some View {
        ZStack {
            // 1. الخلفية (Brand Identity)
            ShiftTheme.appBackground.ignoresSafeArea()

            // تأثير التوهج الخلفي (Ambient Light)
            Circle()
                .fill(ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.15 : 0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(y: -150)
                .allowsHitTesting(false)

            VStack(spacing: 30) {
                Spacer()

                // 2. الشعار والهوية
                VStack(spacing: 24) {
                    
                    ZStack {
                        Circle()
                            .fill(ShiftTheme.ColorToken.brandPrimary.opacity(0.1))
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)

                        Image("Asset")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .shadow(color: ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: 20, x: 0, y: 10)
                    }
                    .scaleEffect(appear ? 1 : 0.8)
                    .opacity(appear ? 1 : 0)
                    .allowsHitTesting(false)

                    VStack(spacing: 8) {
                        Text(tr("نوبتي", "Nubti"))
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundColor(.primary)

                        Text(tr("نظم وقتك.. ارتاح في دوامك", "Manage your time.. stay organized"))
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .offset(y: appear ? 0 : 20)
                    .opacity(appear ? 1 : 0)
                }

                Spacer()

                // 3. الأزرار (Action Area)
                VStack(spacing: 16) {
                    // زر البدء الرئيسي
                    Button {
                        HapticManager.shared.impact(.medium)
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            selection = 1
                        }
                    } label: {
                        HStack {
                            Text(tr("ابدأ الآن", "Get Started"))
                                .font(.headline.bold())
                            
                            // السهم يغير اتجاهه تلقائياً حسب اتجاه اللغة
                            Image(systemName: "arrow.right")
                                .font(.headline.bold())
                                .flipsForRightToLeftLayoutDirection(true)
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
                        .shadow(color: ShiftTheme.ColorToken.brandPrimary.opacity(0.4), radius: 10, x: 0, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .contentShape(Rectangle())

                    // زر التخطي
                    Button {
                        HapticManager.shared.selection()
                        withAnimation {
                            settings.isSetupComplete = true
                        }
                    } label: {
                        Text(tr("تخطي الإعداد", "Skip Setup"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 20)
                .allowsHitTesting(true)
                .zIndex(1)
            }
        }
        .environment(\.layoutDirection, settings.language.direction) // فرض اتجاه الواجهة الصحيح
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                appear = true
            }
        }
    }
}
