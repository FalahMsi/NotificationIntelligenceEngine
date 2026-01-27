import SwiftUI

/// ShiftVerificationView
/// واجهة معالج التحقق من جدول النوبات - تظهر عند اكتشاف خلل في البيانات.
/// جزء من نظام التقوية للوصول إلى مستوى Government-Grade.
///
/// ## Usage
/// This view is presented as a modal sheet when reference date corruption is detected.
/// The user selects their current shift, and the system recalculates the correct reference date.
struct ShiftVerificationView: View {

    // MARK: - Environment
    @ObservedObject var wizard = ShiftVerificationWizard.shared
    @Environment(\.dismiss) private var dismiss

    // MARK: - Language
    private var isArabic: Bool {
        UserDefaults.standard.string(forKey: "app_language") == "ar"
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {

                // Header Icon
                headerIcon

                // Title & Subtitle
                titleSection

                // Phase Selection
                phaseSelectionSection

                Spacer()

                // Action Buttons
                actionButtons
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: handleDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .interactiveDismissDisabled(true) // Prevent swipe-to-dismiss
        }
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
    }

    // MARK: - Header Icon

    private var headerIcon: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.15))
                .frame(width: 80, height: 80)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)
        }
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(spacing: 12) {
            Text(isArabic ? "التحقق من جدول النوبات" : "Verify Your Schedule")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(verificationMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    private var verificationMessage: String {
        if isArabic {
            return "يبدو أن هناك خلل في بيانات جدولك. يرجى اختيار نوبتك لهذا اليوم لإصلاح الجدول."
        } else {
            return "There seems to be an issue with your schedule data. Please select your shift for today to fix the schedule."
        }
    }

    // MARK: - Phase Selection

    private var phaseSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isArabic ? "ما هي نوبتك اليوم؟" : "What is your shift today?")
                .font(.headline)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(wizard.availablePhases, id: \.self) { phase in
                    PhaseSelectionCard(
                        phase: phase,
                        isSelected: wizard.selectedPhase == phase,
                        isArabic: isArabic
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            wizard.selectedPhase = phase
                        }
                    }
                }
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Confirm Button
            Button(action: handleConfirm) {
                HStack {
                    if wizard.state == .processingSelection {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isArabic ? "تأكيد" : "Confirm")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(wizard.selectedPhase != nil ? Color.accentColor : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(wizard.selectedPhase == nil || wizard.state == .processingSelection)

            // Skip Button (uses fallback)
            Button(action: handleSkip) {
                Text(isArabic ? "تخطي الآن" : "Skip for now")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Actions

    private func handleConfirm() {
        guard let selectedPhase = wizard.selectedPhase else { return }
        wizard.completeVerification(todayPhase: selectedPhase)

        // Dismiss after short delay to allow completion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }

    private func handleSkip() {
        wizard.dismiss(useFallback: true)
        dismiss()
    }

    private func handleDismiss() {
        wizard.dismiss(useFallback: true)
        dismiss()
    }
}

// MARK: - Phase Selection Card

private struct PhaseSelectionCard: View {
    let phase: ShiftPhase
    let isSelected: Bool
    let isArabic: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Phase Icon
                Image(systemName: phaseIcon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : phaseColor)

                // Phase Name
                Text(phaseName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? phaseColor : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? phaseColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var phaseIcon: String {
        switch phase {
        case .morning:
            return "sun.max.fill"
        case .evening:
            return "sun.haze.fill"
        case .night:
            return "moon.stars.fill"
        case .off, .firstOff, .secondOff:
            return "house.fill"
        case .weekend:
            return "calendar"
        case .leave:
            return "airplane"
        }
    }

    private var phaseColor: Color {
        switch phase {
        case .morning:
            return .orange
        case .evening:
            return .purple
        case .night:
            return .indigo
        case .off, .firstOff, .secondOff:
            return .green
        case .weekend:
            return .blue
        case .leave:
            return .teal
        }
    }

    private var phaseName: String {
        switch phase {
        case .morning:
            return isArabic ? "دوام صباح" : "Morning"
        case .evening:
            return isArabic ? "دوام عصر" : "Evening"
        case .night:
            return isArabic ? "دوام ليل" : "Night"
        case .off:
            return isArabic ? "راحة" : "Off"
        case .firstOff:
            return isArabic ? "راحة (1)" : "1st Off"
        case .secondOff:
            return isArabic ? "راحة (2)" : "2nd Off"
        case .weekend:
            return isArabic ? "عطلة" : "Weekend"
        case .leave:
            return isArabic ? "إجازة" : "Leave"
        }
    }
}

// MARK: - Preview

#Preview("Verification Wizard") {
    ShiftVerificationView()
}
