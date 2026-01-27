import Foundation
import os.log

/// PDFLogger
/// أداة مساعدة لتتبع وتسجيل عمليات توليد ملفات PDF وتوثيق الأخطاء.
/// تساعد المطور في مراقبة تدفق البيانات والتأكد من حفظ الملفات في المسار الصحيح.
/// تم التحديث: استخدام Logger (os.log) بدلاً من print()
enum PDFLogger {

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.nubti.app", category: "PDF")

    /// تسجيل خطوة برمجية عادية
    static func step(_ message: String) {
        logger.info("🟦 [PDF] \(message)")
    }

    /// تسجيل نجاح عملية معينة
    static func success(_ message: String) {
        logger.info("🟢 [PDF SUCCESS] \(message)")
    }

    /// تسجيل تحذير (مثل وجود بيانات ناقصة لا تعيق التوليد)
    static func warning(_ message: String) {
        logger.warning("🟡 [PDF WARNING] \(message)")
    }

    /// تسجيل خطأ تقني (فشل في الحفظ أو المعالجة)
    static func error(_ message: String, error: Error? = nil) {
        let errorDescription = error?.localizedDescription ?? "Unknown Error"
        logger.error("🔴 [PDF ERROR] \(message) | Details: \(errorDescription)")
    }

    /// عرض تفاصيل الملف المولد في الـ Console
    static func fileInfo(url: URL) {
        let exists = FileManager.default.fileExists(atPath: url.path)
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0

        // تحويل الحجم لميجابايت للقراءة البشرية
        let sizeInMB = Double(size) / (1024 * 1024)
        let formattedSize = String(format: "%.2f MB (%d bytes)", sizeInMB, size)

        logger.debug("📄 [PDF FILE INFO] Status: \(exists ? "✅ Created" : "❌ Not Found") | Size: \(formattedSize) | Name: \(url.lastPathComponent)")
    }
}
