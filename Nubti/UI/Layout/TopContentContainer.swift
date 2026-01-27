import SwiftUI

/// TopContentContainer
/// حاوية قياسية لتوحيد المسافات والهوامش في أعلى الشاشات (Header Area).
/// تم التدقيق: إضافة الهوامش الجانبية لضمان عدم التصاق المحتوى بالحواف.
struct TopContentContainer<Content: View>: View {
    
    // MARK: - Content
    let content: Content
    
    // MARK: - Init
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) { // نجعل المسافة 0 لنعطي التحكم الكامل للمحتوى الداخلي
            content
        }
        // هوامش جانبية موحدة من الثيم
        .padding(.horizontal, ShiftTheme.Layout.horizontalPadding)
        // مسافة علوية آمنة إضافية لجمالية التصميم
        .padding(.top, 16)
        // مسافة سفلية لفصل الترويسة عن القوائم
        .padding(.bottom, 12)
        .background(Color.clear)
    }
}
