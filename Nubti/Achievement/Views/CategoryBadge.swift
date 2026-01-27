import SwiftUI

/// CategoryBadge
/// بطاقة تصنيف الإنجازات
struct CategoryBadge: View {
    let category: AchievementCategory
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 6) {
            // ✅ نستخدم category.icon المعرفة مسبقاً في الموديل
            Image(systemName: category.icon)
                .font(.system(size: 12, weight: .semibold))
            
            // ✅ نستخدم category.localizedName المعرفة مسبقاً في الموديل
            Text(category.localizedName)
                .font(.system(.caption, design: .rounded))
                .bold()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .foregroundStyle(foregroundColor)
        .overlay(
            Capsule().stroke(borderColor, lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    // MARK: - Styles
    
    private var backgroundColor: some ShapeStyle {
        if isSelected {
            return ShiftTheme.ColorToken.brandPrimary.opacity(0.12)
        } else {
            return Color.primary.opacity(0.05)
        }
    }

    private var foregroundColor: some ShapeStyle {
        if isSelected {
            return ShiftTheme.ColorToken.brandPrimary
        } else {
            return Color.primary.opacity(0.6)
        }
    }

    private var borderColor: Color {
        if isSelected {
            return ShiftTheme.ColorToken.brandPrimary.opacity(0.35)
        } else {
            return Color.primary.opacity(0.15)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        CategoryBadge(category: .work, isSelected: false)
        CategoryBadge(category: .work, isSelected: true)
        CategoryBadge(category: .personal, isSelected: false)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
