import SwiftUI
import QuickLook
import UIKit

// MARK: - PDF Preview Screen (Polished UX)

/// PDFPreviewView
/// شاشة المعاينة النهائية للتقارير مع دعم المشاركة والطباعة الفورية.
struct PDFPreviewView: View {

    let url: URL

    @EnvironmentObject private var settings: UserSettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var isLoading = true

    // MARK: - File Validation
    /// التحقق من سلامة الملف قبل عرضه لتجنب الانهيار (Crash)
    private var canPreview: Bool {
        guard FileManager.default.fileExists(atPath: url.path),
              FileManager.default.isReadableFile(atPath: url.path),
              let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        else { return false }

        return size > 0
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // خلفية التطبيق الموحدة
            ShiftTheme.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                headerBar

                Divider()

                ZStack {
                    if canPreview {
                        // محرك المعاينة الأصلي من آبل
                        QuickLookPreview(url: url)
                            .onAppear {
                                // محاكاة تحميل سريع لإعطاء شعور بالاستجابة في الواجهة
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        isLoading = false
                                    }
                                }
                            }
                            .opacity(isLoading ? 0 : 1)

                        if isLoading {
                            loadingOverlay
                        }
                    } else {
                        // حالة الخطأ في حال لم يتم العثور على الملف
                        emptyState
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            AppShareSheet(activityItems: [url])
                // تحديد أحجام العرض المدعومة في نظام iOS الحديث
                .presentationDetents([.medium, .large])
        }
        // ضبط اتجاه الواجهة (يمين/يسار) حسب لغة المستخدم
        .environment(\.layoutDirection, settings.language.direction)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {

            Button {
                HapticManager.shared.impact(.light)
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(10)
                    .background(Circle().fill(Color.secondary.opacity(0.1)))
            }

            Spacer()

            VStack(spacing: 2) {
                Text(tr("معاينة التقرير", "Report Preview"))
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.black)

                Text(url.lastPathComponent)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                HapticManager.shared.selection()
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(
                        canPreview
                        ? ShiftTheme.ColorToken.brandPrimary
                        : .secondary.opacity(0.4)
                    )
                    .padding(10)
            }
            .disabled(!canPreview)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        VStack(spacing: 16) {

            ProgressView()
                .scaleEffect(1.2)
                .tint(ShiftTheme.ColorToken.brandPrimary)

            Text(tr("جاري تحميل المعاينة…", "Loading preview…"))
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.03))
    }

    // MARK: - Empty / Error State

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.primary.opacity(0.04))
                    .frame(width: 120, height: 120)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 44, weight: .thin))
                    .foregroundColor(.secondary.opacity(0.6))
            }

            Text(tr("تعذر عرض التقرير", "Cannot View Report"))
                .font(.system(.headline, design: .rounded))
                .fontWeight(.black)

            Text(tr("لم نتمكن من فتح ملف التقرير.\nقد يكون فشل توليده أو تم حذفه.", "We could not open the report file.\nIt may have failed to generate or was deleted."))
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 32)

            Button {
                HapticManager.shared.impact(.light)
                dismiss()
            } label: {
                Text(tr("العودة", "Back"))
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.black)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
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
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)

            Spacer()
        }
    }
}

//
// MARK: - QuickLook Wrapper
//

/// غلاف لـ QLPreviewController لدمجه في SwiftUI
struct QuickLookPreview: UIViewControllerRepresentable {

    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.currentPreviewItemIndex = 0
        return controller
    }

    func updateUIViewController(
        _ uiViewController: QLPreviewController,
        context: Context
    ) {
        if context.coordinator.url != url {
            context.coordinator.url = url
            uiViewController.reloadData()
        }
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {

        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(
            _ controller: QLPreviewController,
            previewItemAt index: Int
        ) -> QLPreviewItem {
            url as NSURL
        }
    }
}

//
// MARK: - Share Sheet (Safe Wrapper)
//

/// واجهة المشاركة الرسمية لنظام iOS مع حماية للـ iPad
struct AppShareSheet: UIViewControllerRepresentable {

    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // حماية إضافية للـ iPad لمنع الانهيار عند فتح الـ Share Sheet
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIView()
            popover.sourceRect = .zero
        }
        
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) { }
}
