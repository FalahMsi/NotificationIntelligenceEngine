import SwiftUI

/// BottomBarView
/// شريط التنقل السفلي المخصص مع زر عائم وتأثيرات زجاجية
struct BottomBarView: View {
    
    // MARK: - Dependencies
    @EnvironmentObject private var settings: UserSettingsStore
    @Environment(\.colorScheme) var colorScheme
    
    let selectedPage: AppPage
    let onSelect: (AppPage) -> Void
    
    // MARK: - Stores
    @StateObject private var messagesStore = MessagesStore.shared
    
    // MARK: - Derived
    private var currentSystemID: ShiftSystemID {
        UserShift.shared.shiftContext?.systemID ?? .threeShiftTwoOff
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            
            // 1. خلفية البار مع المنحنى الزجاجي
            BottomBarShape()
                .fill(.ultraThinMaterial)
                .overlay(
                    ShiftTheme.appBackground.opacity(colorScheme == .dark ? 0.85 : 0.6)
                )
                .overlay(
                    BottomBarShape()
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.12), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 10, x: 0, y: -5)
                .frame(height: ShiftTheme.Layout.bottomBarHeight)
            
            // 2. محتوى الأزرار (3 Tabs: Leaves + Records | Calendar | Settings)
            // التوزيع المتوازن 2+1: [Leaves] [Records] --- [Floating] --- [Settings]
            HStack(spacing: 0) {

                // --- الجانب الأيسر (2 أزرار) ---
                HStack(spacing: 12) {
                    // زر الإجازات
                    BottomTabItem(
                        icon: "suitcase",
                        title: tr("الإجازات", "Leaves"),
                        isSelected: selectedPage == .leaves
                    ) { onSelect(.leaves) }

                    // زر السجلات (مع شارة النشاط الجديد)
                    BottomTabItem(
                        icon: "doc.text",
                        title: tr("السجلات", "Records"),
                        isSelected: selectedPage == .services,
                        badgeCount: messagesStore.unreadCount
                    ) { onSelect(.services) }
                }

                Spacer()

                // --- المنتصف (مكان الزر العائم) ---
                Spacer().frame(width: ShiftTheme.Layout.floatingButtonSize + 20)

                Spacer()

                // --- الجانب الأيمن (1 زر) ---
                // زر الإعدادات
                BottomTabItem(
                    icon: "gearshape",
                    title: tr("الإعدادات", "Settings"),
                    isSelected: selectedPage == .settings
                ) { onSelect(.settings) }
            }
            .padding(.horizontal, 20)
            .frame(height: ShiftTheme.Layout.bottomBarHeight)
            .padding(.bottom, 15) // مراعاة منطقة الـ Safe Area
            
            // 3. الزر العائم (Calendar Button)
            FloatingCenterButton(
                isSelected: selectedPage == .calendar,
                currentSystem: currentSystemID
            ) {
                onSelect(.calendar)
            }
            .offset(y: -28) // لرفعه فوق مستوى الشريط
            .shadow(color: ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.3 : 0.15), radius: 8, x: 0, y: 4)
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea(edges: .bottom)
        .environment(\.layoutDirection, settings.language.direction)
    }
}

// MARK: - Tab Item Component
private struct BottomTabItem: View {
    @Environment(\.colorScheme) var colorScheme
    
    let icon: String
    let title: String
    let isSelected: Bool
    let badgeCount: Int
    let action: () -> Void
    
    init(icon: String, title: String, isSelected: Bool, badgeCount: Int = 0, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.isSelected = isSelected
        self.badgeCount = badgeCount
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.selection()
            action()
        }) {
            VStack(spacing: 5) {
                ZStack(alignment: .center) {
                    
                    if isSelected {
                        Circle()
                            .fill(ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.15 : 0.12))
                            .frame(width: 40, height: 40)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: isSelected ? "\(icon).fill" : icon)
                            .font(.system(size: 22, weight: isSelected ? .black : .medium))
                            .foregroundColor(isSelected ? ShiftTheme.ColorToken.brandPrimary : .secondary)
                            .scaleEffect(isSelected ? 1.1 : 1.0)
                        
                        if badgeCount > 0 {
                            Text("\(min(badgeCount, 99))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(ShiftTheme.ColorToken.brandDanger))
                                .offset(x: 10, y: -8)
                        }
                    }
                }
                .frame(width: 44, height: 44)
                
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .black : .bold))
                    .foregroundColor(isSelected ? .primary : .secondary.opacity(0.8))
            }
            .offset(y: isSelected ? -8 : 0) // حركة طفيفة عند الاختيار
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Custom Shape
struct BottomBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        return Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            let midpoint = rect.width / 2
            let curveWidth: CGFloat = ShiftTheme.Layout.floatingButtonSize + 25
            let curveHeight: CGFloat = 32
            
            // خط البداية
            path.addLine(to: CGPoint(x: midpoint - (curveWidth / 2) - 15, y: 0))
            
            // رسم المنحنى المركزي
            path.addCurve(
                to: CGPoint(x: midpoint + (curveWidth / 2) + 15, y: 0),
                control1: CGPoint(x: midpoint - (curveWidth / 4), y: curveHeight),
                control2: CGPoint(x: midpoint + (curveWidth / 4), y: curveHeight)
            )
            
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height))
            path.addLine(to: CGPoint(x: 0, y: rect.height))
            path.closeSubpath()
        }
    }
}
