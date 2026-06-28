 import SwiftUI
 import Charts
 
 /// Statistics and insights: mood chart, streak, weekly summaries, keyword tags.
 struct StatsView: View {
     @Environment(JournalViewModel.self) private var journalVM
     @State private var statsVM: StatsViewModel?
     @State private var selectedTimeRange: TimeRange = .week
     
     enum TimeRange: String, CaseIterable {
         case week = "Week"
         case month = "Month"
         var days: Int {
             switch self {
             case .week: return 7
             case .month: return 30
             }
         }
     }
     
     var body: some View {
         NavigationStack {
             ScrollView {
                 VStack(spacing: 20) {
                     if let svm = statsVM {
                         if svm.totalEntries == 0 {
                             emptyState
                         } else {
                             summaryCards(svm: svm)
                             moodChartSection(svm: svm)
                             weeklySummarySection(svm: svm)
                             if !svm.topKeywords.isEmpty { keywordsSection(svm: svm) }
                         }
                     } else {
                         emptyState
                     }
                 }
                 .padding()
             }
             .navigationTitle("Insights")
             .toolbar {
                 ToolbarItem(placement: .navigationBarTrailing) {
                     Button("Refresh") { statsVM?.refresh() }
                 }
             }
             .onAppear {
                 if statsVM == nil {
                     statsVM = StatsViewModel(storage: journalVM.storage)
                 }
                 statsVM?.refresh()
             }
             .onChange(of: journalVM.entries.count) { _, _ in
                 statsVM?.refresh()
             }
         }
     }
     
     private var emptyState: some View {
         VStack(spacing: 16) {
             Image(systemName: "chart.bar.xaxis")
                 .font(.system(size: 48)).foregroundColor(.secondary)
             Text("No data yet").font(.title3).foregroundColor(.secondary)
             Text("Record some journal entries to see insights")
                 .font(.subheadline).foregroundColor(Color.secondary)
         }
         .frame(maxWidth: .infinity).padding(.vertical, 60)
     }
     
     private func summaryCards(svm: StatsViewModel) -> some View {
         LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
             StatCard(title: "Total Entries", value: "\(svm.totalEntries)", icon: "book.fill")
             StatCard(title: "Streak", value: "\(svm.streakDays) days", icon: "flame.fill")
             StatCard(title: "Total Time", value: formatDuration(svm.totalDuration), icon: "clock.fill")
             StatCard(title: "Avg Mood", value: formatSentiment(svm.averageSentiment), icon: "heart.fill")
         }
     }
     
     private func moodChartSection(svm: StatsViewModel) -> some View {
         VStack(alignment: .leading, spacing: 12) {
             HStack {
                 Label("Mood Trend", systemImage: "chart.xyaxis.line").font(.headline)
                 Spacer()
                 Picker("Range", selection: $selectedTimeRange) {
                     ForEach(TimeRange.allCases, id: \.self) { range in
                         Text(range.rawValue).tag(range)
                     }
                 }
                 .pickerStyle(.segmented).frame(width: 140)
             }
             
             let history = svm.sentimentHistory
             if !history.isEmpty {
                 Chart {
                     ForEach(history, id: \.date) { item in
                         LineMark(x: .value("Date", item.date, unit: .day),
                                  y: .value("Mood", item.avgSentiment))
                         .foregroundStyle(.blue.gradient)
                         AreaMark(x: .value("Date", item.date, unit: .day),
                                  y: .value("Mood", item.avgSentiment))
                         .foregroundStyle(.blue.opacity(0.1).gradient)
                     }
                 }
                 .chartYScale(domain: -1...1)
                 .chartYAxis {
                     AxisMarks(values: [-1, 0, 1]) { value in
                         AxisValueLabel {
                             if let v = value.as(Double.self) {
                                 Text(v == -1 ? "😔" : v == 0 ? "😐" : "😊")
                             }
                         }
                     }
                 }
                 .chartXAxis {
                     AxisMarks(values: .stride(by: .day)) { _ in
                         AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                     }
                 }
                 .frame(height: 200)
             } else {
                 Text("Not enough data for chart")
                     .font(.subheadline).foregroundColor(.secondary)
                     .frame(maxWidth: .infinity).padding()
             }
         }
         .padding().background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 16))
     }
     
     private func weeklySummarySection(svm: StatsViewModel) -> some View {
         VStack(alignment: .leading, spacing: 8) {
             Label("Weekly Summary", systemImage: "calendar").font(.headline)
             ForEach(svm.weeklyData.prefix(4), id: \.week) { week in
                 let summary = journalVM.weeklySummary(for: week.week)
                 HStack {
                     VStack(alignment: .leading, spacing: 4) {
                         Text(formatWeekLabel(week.week))
                             .font(.subheadline).fontWeight(.medium)
                         Text(summary).font(.caption).foregroundColor(.secondary)
                     }
                     Spacer()
                 }
                 .padding(12).background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 8))
             }
         }
         .padding().background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 16))
     }
     
     private func keywordsSection(svm: StatsViewModel) -> some View {
         VStack(alignment: .leading, spacing: 8) {
             Label("Top Topics", systemImage: "tag").font(.headline)
             FlowLayout(spacing: 8) {
                 ForEach(svm.topKeywords, id: \.self) { keyword in
                     Text(keyword)
                         .font(.caption)
                         .padding(.horizontal, 12).padding(.vertical, 6)
                         .background(Color.blue.opacity(0.1))
                         .foregroundColor(.blue)
                         .clipShape(Capsule())
                 }
             }
         }
         .padding().background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 16))
     }
     
     // MARK: - Helpers
     private func formatDuration(_ seconds: TimeInterval) -> String {
         let hours = Int(seconds) / 3600
         let minutes = (Int(seconds) % 3600) / 60
         return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
     }
     
     private func formatSentiment(_ value: Double) -> String {
         if value > 0.3 { return "Positive" }
         else if value > -0.3 { return "Mixed" }
         else { return "Reflective" }
     }
     
     private func formatWeekLabel(_ weekId: String) -> String {
         guard !weekId.isEmpty else { return "N/A" }
         let parts = weekId.split(separator: "-")
         guard parts.count == 2, parts[1].hasPrefix("W"),
               let weekNum = Int(parts[1].dropFirst()) else {
             return weekId
         }
         return "Week \(weekNum)"
     }
 }
 
 // MARK: - Stat Card
 struct StatCard: View {
     let title: String
     let value: String
     let icon: String
     
     var body: some View {
         VStack(spacing: 8) {
             Image(systemName: icon).font(.title3).foregroundColor(.accentColor)
             Text(value).font(.title2).fontWeight(.bold)
             Text(title).font(.caption).foregroundColor(.secondary)
         }
         .frame(maxWidth: .infinity).padding()
         .background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 12))
     }
 }
 
 // MARK: - Flow Layout
 struct FlowLayout: Layout {
     var spacing: CGFloat = 8
     
     func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
         guard !subviews.isEmpty else { return .zero }
         let width = proposal.width ?? 0
         guard width > 0 else { return .zero }
         
         var height: CGFloat = 0
         var x: CGFloat = 0
         var y: CGFloat = 0
         
         for view in subviews {
             let size = view.sizeThatFits(.unspecified)
             if x + size.width > width && x > 0 {
                 x = 0
                 y += size.height + spacing
             }
             x += size.width + spacing
             height = y + size.height
         }
         return CGSize(width: width, height: height)
     }
     
     func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
         guard !subviews.isEmpty, bounds.width > 0 else { return }
         
         var x = bounds.minX
         var y = bounds.minY
         
         for view in subviews {
             let size = view.sizeThatFits(.unspecified)
             if x + size.width > bounds.maxX && x > bounds.minX {
                 x = bounds.minX
                 y += size.height + spacing
             }
             view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
             x += size.width + spacing
         }
     }
 }
 
 // MARK: - Preview
 #Preview("Stats with data") {
     StatsView()
         .environment(JournalViewModel())
 }


