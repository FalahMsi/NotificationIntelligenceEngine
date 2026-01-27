import SwiftUI

struct ManualLeaveAddButton: View {
    
    @EnvironmentObject private var settings: UserSettingsStore
    @State private var showSheet = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button {
            HapticManager.shared.selection()
            showSheet = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .black))
                
                Text(tr("تسجيل إجازة جديدة", "Register New Leave"))
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        ShiftTheme.ColorToken.brandPrimary,
                        ShiftTheme.ColorToken.brandInfo
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: ShiftTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ShiftTheme.Radius.md, style: .continuous)
                    .stroke(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.3), lineWidth: 1.5)
            )
            .shadow(
                color: ShiftTheme.ColorToken.brandPrimary.opacity(colorScheme == .dark ? 0.4 : 0.25),
                radius: 12, x: 0, y: 6
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) {
            ManualLeaveEntryView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .accessibilityLabel(tr("إضافة إجازة يدوية", "Add manual leave"))
        .accessibilityHint(tr("يفتح نموذجاً لتسجيل إجازة جديدة", "Opens a form to register a new leave"))
    }
}
