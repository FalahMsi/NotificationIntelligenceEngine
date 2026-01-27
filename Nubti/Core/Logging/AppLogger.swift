import Foundation
import os.log

/// AppLogger
/// Structured logging utility for Duami app observability.
/// Uses Apple's OSLog for efficient, categorized logging.
///
/// Phase 3: Error Resilience & Trust Observability
/// - Replaces print() statements for production-grade logging
/// - Provides context-rich logs for debugging without Xcode console
/// - Non-blocking, crash-safe logging
///
/// Usage:
/// ```swift
/// AppLogger.notification.info("Notification scheduled", context: ["id": id, "date": dateStr])
/// AppLogger.notification.error("Failed to schedule", context: ["id": id, "error": error.localizedDescription])
/// ```
enum AppLogger {

    // MARK: - Categories

    /// Notification-related events (scheduling, verification, failures)
    static let notification = Logger(subsystem: subsystem, category: "Notifications")

    /// Shift engine calculations
    static let shift = Logger(subsystem: subsystem, category: "ShiftEngine")

    /// User settings and preferences
    static let settings = Logger(subsystem: subsystem, category: "Settings")

    /// General app events
    static let general = Logger(subsystem: subsystem, category: "General")

    // MARK: - Configuration

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.duami.app"

    // MARK: - Convenience Extensions
}

// MARK: - Logger Extension for Context-Rich Logging

extension Logger {

    /// Log info message with optional context dictionary
    /// - Parameters:
    ///   - message: The log message
    ///   - context: Optional dictionary of context values
    func info(_ message: String, context: [String: Any]? = nil) {
        if let context = context {
            let contextStr = context.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            self.log(level: .info, "\(message, privacy: .public) [\(contextStr, privacy: .public)]")
        } else {
            self.log(level: .info, "\(message, privacy: .public)")
        }
    }

    /// Log warning message with optional context dictionary
    /// - Parameters:
    ///   - message: The log message
    ///   - context: Optional dictionary of context values
    func warning(_ message: String, context: [String: Any]? = nil) {
        if let context = context {
            let contextStr = context.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            self.log(level: .error, "⚠️ \(message, privacy: .public) [\(contextStr, privacy: .public)]")
        } else {
            self.log(level: .error, "⚠️ \(message, privacy: .public)")
        }
    }

    /// Log error message with optional context dictionary
    /// - Parameters:
    ///   - message: The log message
    ///   - context: Optional dictionary of context values
    func error(_ message: String, context: [String: Any]? = nil) {
        if let context = context {
            let contextStr = context.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            self.log(level: .fault, "❌ \(message, privacy: .public) [\(contextStr, privacy: .public)]")
        } else {
            self.log(level: .fault, "❌ \(message, privacy: .public)")
        }
    }

    /// Log debug message with optional context dictionary
    /// - Parameters:
    ///   - message: The log message
    ///   - context: Optional dictionary of context values
    func debug(_ message: String, context: [String: Any]? = nil) {
        if let context = context {
            let contextStr = context.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            self.log(level: .debug, "\(message, privacy: .public) [\(contextStr, privacy: .public)]")
        } else {
            self.log(level: .debug, "\(message, privacy: .public)")
        }
    }
}

// MARK: - Notification-Specific Logging Helpers

extension AppLogger {

    /// Log notification scheduled event
    static func logNotificationScheduled(id: String, triggerDate: Date, type: String) {
        let formatter = ISO8601DateFormatter()
        notification.info("Notification scheduled", context: [
            "id": id,
            "triggerDate": formatter.string(from: triggerDate),
            "type": type
        ])
    }

    /// Log notification verification (foreground or interaction)
    static func logNotificationVerified(id: String, source: String) {
        notification.info("Notification verified", context: [
            "id": id,
            "source": source
        ])
    }

    /// Log notification scheduling failure
    static func logNotificationFailed(id: String, triggerDate: Date, error: String) {
        let formatter = ISO8601DateFormatter()
        notification.error("Notification scheduling failed", context: [
            "id": id,
            "triggerDate": formatter.string(from: triggerDate),
            "error": error
        ])
    }

    /// Log notification batch scheduled
    static func logNotificationBatchScheduled(count: Int, dateRange: String) {
        notification.info("Notification batch scheduled", context: [
            "count": count,
            "dateRange": dateRange
        ])
    }

    /// Log notification batch failed
    static func logNotificationBatchFailed(successCount: Int, failCount: Int) {
        notification.warning("Notification batch completed with failures", context: [
            "success": successCount,
            "failed": failCount
        ])
    }
}
