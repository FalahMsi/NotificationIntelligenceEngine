import SwiftUI

/// PDFDiagnosticsOverlay
/// Overlay تشخيصي للتقارير (يظهر فقط في DEBUG)
struct PDFDiagnosticsOverlay: View {

    let reportMode: ReportMode
    let startDate: Date
    let endDate: Date
    let shiftContext: ShiftContext?
    let achievementsCount: Int
    let pdfSize: Int?
    let isGenerating: Bool

    // التاريخ يتبع لغة التطبيق (للتوافق مع التقرير)
    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: UserSettingsStore.shared.language.rawValue)
        f.dateStyle = .medium
        return f
    }

    var body: some View {
#if DEBUG
        VStack(alignment: .leading, spacing: 6) {

            header

            row("Mode", reportMode.rawValue)
            row("From", dateFormatter.string(from: startDate))
            row("To", dateFormatter.string(from: endDate))

            Divider().opacity(0.4)

            if let context = shiftContext {
                row("ShiftSystem", context.systemID.rawValue)
                row("Reference", dateFormatter.string(from: context.referenceDate))
            } else {
                row("ShiftContext", "❌ nil")
                    .foregroundColor(.red)
            }

            row("Achievements", "\(achievementsCount)")
            row("PDF Size", pdfSize.map { "\($0) bytes" } ?? "—")

            Divider().opacity(0.4)

            row("State", isGenerating ? "⏳ Generating" : "✅ Idle")
        }
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
        )
        .foregroundColor(.white)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)

        // ✅ تثبيت الاتجاه LTR (تشخيص فقط – أرقام ومفاتيح)
        .environment(\.layoutDirection, .leftToRight)
#endif
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text("PDF Diagnostics")
                .font(.system(size: 12, weight: .black, design: .rounded))

            Spacer()

            Text("DEBUG")
                .font(.system(size: 10, weight: .black))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red)
                .clipShape(Capsule())
        }
    }

    // MARK: - Row
    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text("\(title):")
                .foregroundColor(.gray)

            Spacer()

            // القيم دائماً LTR (أرقام/رموز)
            Text(value)
                .environment(\.layoutDirection, .leftToRight)
        }
    }
}
