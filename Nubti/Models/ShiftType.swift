import Foundation
import SwiftUI

/// ShiftType
/// UI Identity ONLY
/// ❌ No scheduling logic
/// ❌ No time / system meaning
enum ShiftType: Int, CaseIterable, Codable {

    case A = 0
    case B
    case C
    case D
    case F

    // MARK: - Display

    /// Stable display symbol (UI-only)
    var symbol: String {
        String(describing: self)
    }

    // MARK: - Colors (Premium Palette)
    
    /// قاعدة الألوان المحسنة لتناسب الدارك مود والخلفيات العميقة
    private var baseColor: Color {
        switch self {
        case .A: return .orange
        case .B: return .blue
        case .C: return .purple // تم استبدال الـ Indigo بـ Purple لعمق أكبر
        case .D: return Color(white: 0.6) // رصاصي معدني
        case .F: return .secondary
        }
    }

    /// اللون الأساسي للنصوص والأيقونات (أكثر حدة للوضوح)
    var tintColor: Color {
        switch self {
        case .D, .F: return baseColor // الألوان الحيادية لا تحتاج تغيير
        default: return baseColor.opacity(0.95)
        }
    }

    /// لون الخلفية للخلية (تأثير الزجاج الملون)
    var backgroundColor: Color {
        // زيادة الشفافية قليلاً لتندمج مع خلفية التطبيق الجديدة
        baseColor.opacity(0.18)
    }
    
    /// إطار ناعم حول الخلية لزيادة التحديد
    var strokeColor: Color {
        baseColor.opacity(0.3)
    }

    // MARK: - Decorative Icons
    
    /// تم تحديث الأيقونات لتكون أكثر تناسقاً هندسياً
    var icon: String {
        switch self {
        case .A: return "hexagon.fill"
        case .B: return "square.fill"
        case .C: return "pentagon.fill"
        case .D: return "circle.fill"
        case .F: return "circle.dotted"
        }
    }
}
