import SwiftUI

/// LeavesSettingsView
/// مركز التقارير والسجلات: يجمع لوحة القيادة، سجل الإجازات، وأدوات التصدير.
struct LeavesSettingsView: View {
    
    @EnvironmentObject private var settings: UserSettingsStore
    @Environment(\.colorScheme) var colorScheme
    
    // حالات العرض للصفحات الفرعية
    @State private var showWorkDaysSummary = false
    @State private var showLeaveSummary = false
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                
                // MARK: - 1. التحليلات المرئية
                SectionHeader(title: tr("التحليلات", "Analytics"), language: settings.language)
                
                NavigationLink {
                    WorkDashboardView()
                        .environmentObject(settings)
                } label: {
                    LeavesSettingsRow(
                        icon: "chart.pie.fill",
                        iconColor: .blue,
                        title: tr("لوحة العمل", "Work Dashboard"),
                        subtitle: tr("إحصائيات الحضور والخصومات", "Attendance stats & deductions"),
                        language: settings.language
                    )
                }
                .buttonStyle(.plain)
                
                // MARK: - 2. السجلات التفصيلية
                SectionHeader(title: tr("السجلات", "Logs"), language: settings.language)
                
                NavigationLink {
                    ManualLeavesListView()
                } label: {
                    LeavesSettingsRow(
                        icon: "list.bullet.rectangle.portrait.fill",
                        iconColor: .indigo,
                        title: tr("سجل الإجازات", "Leaves Log"),
                        subtitle: tr("قائمة وتعديل الإجازات اليدوية", "List & edit manual leaves"),
                        language: settings.language
                    )
                }
                .buttonStyle(.plain)
                
                // MARK: - 3. التصدير والطباعة
                SectionHeader(title: tr("التقارير الرسمية (PDF)", "Official Reports"), language: settings.language)
                
                VStack(spacing: 12) {
                    // تقرير دوام تفصيلي
                    Button {
                        showWorkDaysSummary = true
                    } label: {
                        LeavesSettingsRow(
                            icon: "doc.text.fill",
                            iconColor: .green,
                            title: tr("تقرير الدوام", "Work Report"),
                            subtitle: tr("طباعة كشف الدوام والإجازات", "Print shift & leave statement"),
                            language: settings.language
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // تقرير أرصدة الإجازات
                    Button {
                        showLeaveSummary = true
                    } label: {
                        LeavesSettingsRow(
                            icon: "briefcase.fill",
                            iconColor: .orange,
                            title: tr("ملخص الإجازات", "Leaves Summary"),
                            subtitle: tr("طباعة أرصدة وأنواع الإجازات", "Print leave balances & types"),
                            language: settings.language
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer(minLength: 40)
            }
            .padding(.horizontal)
            .padding(.top, 16)
        }
        .background(Color.clear)
        .navigationTitle(tr("التقارير والسجلات", "Reports & Logs"))
        .navigationBarTitleDisplayMode(.inline)
        // أوراق التصدير
        .sheet(isPresented: $showWorkDaysSummary) {
            WorkDaysSummarySheet().environmentObject(settings)
        }
        .sheet(isPresented: $showLeaveSummary) {
            ManualLeavesSummarySheet().environmentObject(settings)
        }
    }
}

// MARK: - Helper Components

/// مكون صف موحد التصميم (مطابق لـ SettingsView)
struct LeavesSettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let language: AppLanguage
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(spacing: 16) {
            // الأيقونة
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.12))
                .cornerRadius(12)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // سهم التوجيه (يدعم RTL)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.secondary.opacity(0.5))
                .flipsForRightToLeftLayoutDirection(true)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0 : 0.03), radius: 8, y: 3)
    }
}
