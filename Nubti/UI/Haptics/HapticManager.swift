import UIKit

/// HapticManager
/// المصدر الوحيد للـ Haptics في التطبيق
/// مطابق لـ Apple HIG (خفيف وغير مزعج)
final class HapticManager {

    // MARK: - Singleton
    static let shared = HapticManager()
    private init() {}

    // MARK: - Cached Generators

    private let selectionGenerator: UISelectionFeedbackGenerator = {
        let g = UISelectionFeedbackGenerator()
        g.prepare()
        return g
    }()

    private let notificationGenerator: UINotificationFeedbackGenerator = {
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        return g
    }()

    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)

    // MARK: - Impact

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator: UIImpactFeedbackGenerator

        switch style {
        case .light:
            generator = impactLight
        case .medium:
            generator = impactMedium
        case .heavy:
            generator = impactHeavy
        default:
            generator = UIImpactFeedbackGenerator(style: style)
        }

        generator.impactOccurred()
        generator.prepare()
    }

    // MARK: - Selection

    func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    // MARK: - Notification

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        notificationGenerator.prepare()
    }

    // MARK: - Convenience

    func light() {
        impact(.light)
    }

    func medium() {
        impact(.medium)
    }

    func heavy() {
        impact(.heavy)
    }
}
