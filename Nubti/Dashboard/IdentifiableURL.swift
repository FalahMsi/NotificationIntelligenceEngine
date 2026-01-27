import Foundation

public struct IdentifiableURL: Identifiable, Equatable {

    // ✅ هوية مستقلة لكل عرض
    public let id: UUID
    public let url: URL

    public init(url: URL) {
        self.id = UUID()
        self.url = url
    }

    // Equatable مطلوب لبعض حالات SwiftUI
    public static func == (
        lhs: IdentifiableURL,
        rhs: IdentifiableURL
    ) -> Bool {
        lhs.id == rhs.id
    }
}
