import SwiftUI

/// ShiftTheme
/// نظام التصميم المركزي (Design System) لتطبيق دوامي.
/// تم التدقيق: تحسين التباين في الوضع النهاري، وتوحيد منطق الظلال والكروت.
enum ShiftTheme {

    // MARK: - App Colors (Adaptive Identity)
    
    /// خلفية التطبيق الذكية: تتكيف لضمان أفضل تباين للمحتوى الزجاجي
    static var appBackground: Color {
        Color(UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                // الوضع الليلي: بنفسجي غامق جداً (فخم ومريح للعين)
                return UIColor(red: 15/255, green: 13/255, blue: 19/255, alpha: 1.0)
            } else {
                // الوضع النهاري: رمادي فاتح بارد (لإبراز الكروت البيضاء)
                return UIColor(red: 242/255, green: 242/255, blue: 247/255, alpha: 1.0)
            }
        })
    }
    
    // MARK: - Opacity Levels
    enum Opacity {
        static let subtle: Double = 0.05
        static let light: Double  = 0.10
        static let medium: Double = 0.15
        static let strong: Double = 0.25
        static let interactive: Double = 0.7
    }

    // MARK: - Brand Colors (Semantic Tokens)
    enum ColorToken {
        static let brandPrimary = Color.blue
        static let brandSuccess = Color.green
        static let brandWarning = Color.orange
        static let brandDanger  = Color.red
        static let brandInfo    = Color.indigo
        static let brandRelief  = Color.teal

        // MARK: - Light Mode Adjusted Colors

        /// Off-day state — slightly darkened for better contrast on Light Mode canvas
        static var offDay: Color {
            Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 99/255, green: 99/255, blue: 102/255, alpha: 1.0) // #636366
                } else {
                    return UIColor(red: 124/255, green: 124/255, blue: 128/255, alpha: 1.0) // #7C7C80
                }
            })
        }

        /// Permission/Warning — darkened for Light Mode contrast
        static var permission: Color {
            Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 255/255, green: 159/255, blue: 10/255, alpha: 1.0) // #FF9F0A
                } else {
                    return UIColor(red: 232/255, green: 136/255, blue: 0/255, alpha: 1.0) // #E88800
                }
            })
        }
    }

    // MARK: - Group Identification Colors
    static func groupColor(for group: String?) -> Color {
        switch group {
        case "A": return .blue
        case "B": return .green
        case "C": return .orange
        case "D": return .purple
        case "F": return .secondary
        default:  return .accentColor
        }
    }

    static func groupColor(for group: ShiftType?) -> Color {
        groupColor(for: group?.symbol)
    }

    static func groupTint(for group: String?) -> Color {
        groupColor(for: group).opacity(Opacity.light)
    }

    // MARK: - Calendar Colors (Premium Refined Palette)
    /// ألوان التقويم المحسّنة - تصميم راقي وهادئ
    enum CalendarColors {
        /// Morning shift: Warm amber - fresh, energetic
        static var morningShift: Color {
            Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 251/255, green: 191/255, blue: 36/255, alpha: 1.0)  // Brighter for dark
                } else {
                    return UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0)  // #F59E0B
                }
            })
        }

        /// Evening shift: Soft coral/peach - transition feeling
        static var eveningShift: Color {
            Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 251/255, green: 146/255, blue: 60/255, alpha: 1.0)  // Brighter for dark
                } else {
                    return UIColor(red: 249/255, green: 115/255, blue: 22/255, alpha: 1.0)  // #F97316
                }
            })
        }

        /// Night shift: Deep indigo - calm night tone
        static var nightShift: Color {
            Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 129/255, green: 140/255, blue: 248/255, alpha: 1.0)  // Brighter for dark
                } else {
                    return UIColor(red: 99/255, green: 102/255, blue: 241/255, alpha: 1.0)  // #6366F1
                }
            })
        }

        /// Off day: Slate gray - visible but calm
        static var offDay: Color {
            Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0)  // Lighter slate
                } else {
                    return UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)  // #64748B
                }
            })
        }

        /// Today glow color
        static let todayGlow = Color.white

        /// Row separator
        static let rowSeparator = Color.primary.opacity(0.04)

        /// Month divider
        static let monthDivider = Color.primary.opacity(0.06)
    }

    // MARK: - Shift Phase Indicators
    static func phaseIndicatorColor(_ phase: ShiftPhase) -> Color {
        switch phase {
        case .morning:
            return CalendarColors.morningShift
        case .evening:
            return CalendarColors.eveningShift
        case .night:
            return CalendarColors.nightShift
        case .off, .firstOff, .secondOff:
            return CalendarColors.offDay
        case .weekend:
            return ColorToken.brandDanger
        case .leave:
            return ColorToken.brandDanger
        }
    }

    static func phaseBackground(_ phase: ShiftPhase) -> Color {
        let baseColor = phaseIndicatorColor(phase)
        switch phase {
        case .off, .firstOff, .secondOff:
            return baseColor.opacity(0.08)  // More visible for off days
        default:
            return baseColor.opacity(Opacity.light)
        }
    }

    // MARK: - Layout Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // MARK: - Corner Radii
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let full: CGFloat = 999
    }

    // MARK: - Shadow System (Light Mode Depth)
    /// Three-tier shadow system for visual hierarchy in Light Mode
    enum Shadow {
        /// Level 1: Subtle card separation (message rows, list items)
        static let cardOpacity: Double = 0.04
        static let cardRadius: CGFloat = 3
        static let cardY: CGFloat = 1

        /// Level 2: Floating elements (status cards, modals)
        static let floatingOpacity: Double = 0.06
        static let floatingRadius: CGFloat = 8
        static let floatingY: CGFloat = 2

        /// Level 3: Sheet/overlay backgrounds
        static let sheetOpacity: Double = 0.08
        static let sheetRadius: CGFloat = 16
        static let sheetY: CGFloat = 4
    }
    
    // MARK: - Layout Dimensions
    enum Layout {
        static let bottomBarHeight: CGFloat = 85
        static let floatingButtonSize: CGFloat = 65

        static var bottomContentPadding: CGFloat {
            return bottomBarHeight + 20
        }

        static let horizontalPadding: CGFloat = 20
    }

    // MARK: - Animation Constants
    /// Standardized animation durations and curves for consistent micro-interactions
    enum Animation {
        // MARK: Durations
        /// Quick feedback (tap response, selection change)
        static let quick: Double = 0.15
        /// Standard transition (state changes, toggles)
        static let standard: Double = 0.25
        /// Smooth entrance (charts, cards appearing)
        static let smooth: Double = 0.4
        /// Calm reveal (sheets, modals)
        static let calm: Double = 0.6

        // MARK: SwiftUI Animations
        /// For selection feedback (filter chips, toggles)
        static var selection: SwiftUI.Animation {
            .easeInOut(duration: quick)
        }
        /// For state transitions (read/unread, expand/collapse)
        static var transition: SwiftUI.Animation {
            .easeInOut(duration: standard)
        }
        /// For content appearing (lists, cards)
        static var appear: SwiftUI.Animation {
            .easeOut(duration: smooth)
        }
        /// For sheets and modals
        static var sheet: SwiftUI.Animation {
            .spring(response: calm, dampingFraction: 0.85)
        }
    }
}

// MARK: - Global View Modifiers

extension View {
    
    /// تطبيق خلفية التطبيق الموحدة
    func applyAppBackground() -> some View {
        self.background(ShiftTheme.appBackground.ignoresSafeArea())
    }
    
    /// تطبيق نمط الكروت القياسي (Glassmorphism + Shadow)
    func standardCardStyle() -> some View {
        self.padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: ShiftTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ShiftTheme.Radius.md, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
            )
            // ظل ذكي يتكيف مع الوضع النهاري والليلي
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }
    
    /// نمط الأيقونات الملونة داخل القوائم
    func brandIconStyle(color: Color) -> some View {
        self.font(.system(size: 20, weight: .semibold))
            .foregroundColor(color)
            .frame(width: 42, height: 42)
            .background(
                color.opacity(0.12)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    /// إزالة الخلفية الافتراضية للقوائم
    func cleanBackground() -> some View {
        self.background(Color.clear)
    }

    // MARK: - Tier-based Shadow Modifiers (Light Mode Depth)

    /// Level 1: Subtle card separation for message rows, list items
    func cardShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(ShiftTheme.Shadow.cardOpacity),
            radius: ShiftTheme.Shadow.cardRadius,
            x: 0,
            y: ShiftTheme.Shadow.cardY
        )
    }

    /// Level 2: Floating elements like status cards, dialogs
    func floatingShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(ShiftTheme.Shadow.floatingOpacity),
            radius: ShiftTheme.Shadow.floatingRadius,
            x: 0,
            y: ShiftTheme.Shadow.floatingY
        )
    }

    /// Level 3: Sheet/overlay backgrounds
    func sheetShadow() -> some View {
        self.shadow(
            color: Color.black.opacity(ShiftTheme.Shadow.sheetOpacity),
            radius: ShiftTheme.Shadow.sheetRadius,
            x: 0,
            y: ShiftTheme.Shadow.sheetY
        )
    }
}

// MARK: - Reduce Motion Aware Animation

/// A view modifier that respects the Reduce Motion accessibility setting
struct ReduceMotionAwareAnimation: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: UUID())
    }
}

extension View {
    /// Applies animation only if Reduce Motion is not enabled
    /// - Parameter animation: The animation to apply when Reduce Motion is off
    func animateIfAllowed(_ animation: Animation = ShiftTheme.Animation.transition) -> some View {
        modifier(ReduceMotionAwareModifier(animation: animation))
    }
}

/// Internal modifier for reduce motion handling
private struct ReduceMotionAwareModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.animation(animation, value: UUID())
        }
    }
}
