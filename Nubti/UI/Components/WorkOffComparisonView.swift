import SwiftUI

/// WorkOffComparisonView
/// Apple Health–style ratio display comparing work vs off days.
///
/// Visual structure:
/// - Two side-by-side stat cards
/// - Work on left/leading, Off on right/trailing
/// - Large numbers with subtle labels
/// - Optional ratio indicator
///
/// Design principles:
/// - Calm, minimal, non-noisy
/// - Semantic colors for meaning
/// - Subtle appear animation
/// - Read-only (no interactions)
struct WorkOffComparisonView: View {

    // MARK: - Input Data

    /// Work days count
    let workDays: Int

    /// Off days count
    let offDays: Int

    // MARK: - Configuration

    /// Show ratio text (e.g., "3:1")
    var showRatio: Bool = true

    /// Compact mode (smaller cards)
    var isCompact: Bool = false

    /// Language for labels
    var language: AppLanguage = .arabic

    // MARK: - Animation State

    @State private var animationProgress: CGFloat = 0

    // MARK: - Environment

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        VStack(spacing: isCompact ? 12 : 16) {
            // Cards row
            HStack(spacing: isCompact ? 12 : 16) {
                // Work card
                statCard(
                    value: workDays,
                    label: tr("عمل", "Work"),
                    icon: "briefcase.fill",
                    color: ShiftTheme.ColorToken.brandPrimary
                )

                // Divider with ratio
                if showRatio {
                    ratioDivider
                }

                // Off card
                statCard(
                    value: offDays,
                    label: tr("راحة", "Off"),
                    icon: "moon.zzz.fill",
                    color: ShiftTheme.ColorToken.brandRelief
                )
            }
        }
        .opacity(animationProgress)
        .scaleEffect(animationProgress == 0 ? 0.95 : 1.0)
        .onAppear {
            startAnimation()
        }
    }

    // MARK: - Stat Card

    private func statCard(
        value: Int,
        label: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(spacing: isCompact ? 8 : 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(colorScheme == .dark ? 0.15 : 0.12))
                    .frame(width: isCompact ? 36 : 44, height: isCompact ? 36 : 44)

                Image(systemName: icon)
                    .font(.system(size: isCompact ? 16 : 20, weight: .bold))
                    .foregroundColor(color)
            }

            // Value
            Text("\(value)")
                .font(.system(size: isCompact ? 28 : 36, weight: .black, design: .rounded))
                .foregroundColor(.primary)

            // Label
            Text(label)
                .font(.system(size: isCompact ? 11 : 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isCompact ? 16 : 20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Ratio Divider

    private var ratioDivider: some View {
        VStack(spacing: 4) {
            // Ratio text
            Text(ratioText)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.secondary)

            // Colon indicator
            Text(":")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .frame(width: 40)
    }

    // MARK: - Calculations

    /// Simplified ratio (e.g., "3:1" or "2:1")
    private var ratioText: String {
        guard offDays > 0 else {
            return workDays > 0 ? "\(workDays):0" : "0:0"
        }

        let gcd = greatestCommonDivisor(workDays, offDays)
        let simplifiedWork = workDays / max(gcd, 1)
        let simplifiedOff = offDays / max(gcd, 1)

        // If simplified values are too large, use rounded ratio
        if simplifiedWork > 9 || simplifiedOff > 9 {
            let ratio = Double(workDays) / Double(offDays)
            if ratio >= 1 {
                return "\(Int(round(ratio))):1"
            } else {
                let inverseRatio = Double(offDays) / Double(workDays)
                return "1:\(Int(round(inverseRatio)))"
            }
        }

        return "\(simplifiedWork):\(simplifiedOff)"
    }

    private func greatestCommonDivisor(_ a: Int, _ b: Int) -> Int {
        if b == 0 { return a }
        return greatestCommonDivisor(b, a % b)
    }

    // MARK: - Animation

    private func startAnimation() {
        if reduceMotion {
            animationProgress = 1
        } else {
            withAnimation(.easeOut(duration: 0.5)) {
                animationProgress = 1
            }
        }
    }
}

// MARK: - Empty State

extension WorkOffComparisonView {

    var isEmpty: Bool {
        workDays == 0 && offDays == 0
    }

    static func emptyState(isCompact: Bool = false) -> some View {
        HStack(spacing: isCompact ? 12 : 16) {
            emptyCard(isCompact: isCompact)

            VStack(spacing: 4) {
                Text("—")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.3))
            }
            .frame(width: 40)

            emptyCard(isCompact: isCompact)
        }
    }

    private static func emptyCard(isCompact: Bool) -> some View {
        VStack(spacing: isCompact ? 8 : 12) {
            Circle()
                .fill(Color.primary.opacity(0.04))
                .frame(width: isCompact ? 36 : 44, height: isCompact ? 36 : 44)

            Text("—")
                .font(.system(size: isCompact ? 28 : 36, weight: .black, design: .rounded))
                .foregroundColor(.secondary.opacity(0.3))

            Text(tr("لا بيانات", "No data"))
                .font(.system(size: isCompact ? 11 : 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, isCompact ? 16 : 20)
        .background(Color.primary.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: isCompact ? 16 : 20, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Work vs Off - Normal") {
    VStack(spacing: 32) {
        WorkOffComparisonView(
            workDays: 22,
            offDays: 8
        )

        WorkOffComparisonView(
            workDays: 15,
            offDays: 15
        )

        WorkOffComparisonView(
            workDays: 6,
            offDays: 2,
            isCompact: true
        )
    }
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Work vs Off - Empty") {
    WorkOffComparisonView.emptyState()
        .padding()
        .background(Color(.systemBackground))
}
