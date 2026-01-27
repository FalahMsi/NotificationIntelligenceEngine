import SwiftUI

struct ShiftGroupPickerSheet: View {
    
    // MARK: - Dependencies
    @EnvironmentObject private var settings: UserSettingsStore
    
    // ✅ الإصلاح: استخدام @ObservedObject لأن UserShift هو Singleton مشترك
    @ObservedObject private var userShift = UserShift.shared
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Data
    private let groups: [ShiftType] = [.A, .B, .C, .D, .F]
    
    var body: some View {
        ZStack {
            // الخلفية التكيفية من الثيم
            ShiftTheme.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // مقبض السحب
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 12)
                
                // الترويسة
                HStack {
                    Text(tr("اختيار المجموعة", "Select Group"))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    } label: {
                        Text(tr("تم", "Done"))
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(ShiftTheme.ColorToken.brandPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(ShiftTheme.ColorToken.brandPrimary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
                .padding(20)
                
                // القائمة
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach(groups, id: \.rawValue) { group in
                            GroupOptionRow(
                                group: group,
                                isSelected: isSelected(group),
                                language: settings.language,
                                action: { selectGroup(group) }
                            )
                        }
                    }
                    .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
                    .padding(.bottom, 30)
                }
            }
        }
        // ضبط اتجاه الواجهة
        .environment(\.layoutDirection, settings.language.direction)
    }
    
    // MARK: - Selection Logic
    
    private func isSelected(_ group: ShiftType) -> Bool {
        userShift.groupSymbol == group.symbol
    }
    
    private func selectGroup(_ group: ShiftType) {
        guard userShift.groupSymbol != group.symbol else { return }
        HapticManager.shared.selection()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            userShift.updateGroupSymbol(group.symbol)
        }
    }
}

// MARK: - Subviews

struct GroupOptionRow: View {
    let group: ShiftType
    let isSelected: Bool
    let language: AppLanguage
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var groupColor: Color {
        ShiftTheme.groupColor(for: group.symbol)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                
                // أيقونة الحرف
                ZStack {
                    Circle()
                        .fill(isSelected ? groupColor : Color.primary.opacity(0.05))
                        .frame(width: 46, height: 46)
                    
                    Text(group.symbol)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
                
                // النص التكيفي
                VStack(alignment: .leading, spacing: 2) {
                    let groupLabel = language == .arabic ? "المجموعة" : "Group"
                    Text("\(groupLabel) \(group.symbol)")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(isSelected ? .black : .bold)
                        .foregroundColor(isSelected ? .primary : .secondary)
                }
                
                Spacer()
                
                // علامة الاختيار
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(groupColor)
                        .shadow(color: groupColor.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 5)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(14)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(groupColor.opacity(colorScheme == .dark ? 0.1 : 0.08))
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.ultraThinMaterial)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        isSelected ? groupColor.opacity(0.6) : Color.primary.opacity(0.08),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.03), radius: 10, y: 4)
            .scaleEffect(isSelected ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
    }
}
