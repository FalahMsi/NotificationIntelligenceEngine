import SwiftUI

struct PageContainerModifier: ViewModifier {
    
    // هل الصفحة تحتاج مسافة للبوتوم بار؟
    var withBottomBar: Bool
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        ZStack {
            // 1. الخلفية الموحدة (تتغير تلقائياً حسب وضع النظام)
            ShiftTheme.appBackground
                .ignoresSafeArea()
            
            // 2. المحتوى مع مراعاة مساحة الـ Bottom Bar الزجاجي
            content
                .padding(.bottom, withBottomBar ? ShiftTheme.Layout.bottomContentPadding : 0)
        }
        // إخفاء الكيبورد تلقائياً
        .onTapGesture {
            hideKeyboard()
        }
        // ✅ التعديل: حذفنا .preferredColorScheme(.dark)
        // لتمكين دعم وضع النهار الفاخر الذي صممناه
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

extension View {
    /// تطبيق قواعد الصفحة القياسية (خلفية تكيفية، Safe Area للبوتوم بار)
    func applyPageStyle(withBottomBar: Bool = true) -> some View {
        self.modifier(PageContainerModifier(withBottomBar: withBottomBar))
    }
}
