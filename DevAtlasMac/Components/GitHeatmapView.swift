import SwiftUI

/// A heatmap view displaying Git contribution statistics
struct GitHeatmapView: View {
    let stats: [GitDailyStat]
    let dateRange: DateRangeFilter
    
    @State private var hoveredDate: Date? = nil
    @State private var hoveredAmount: Int = 0
    
    // Group stats by day
    private var statsByDate: [Date: Int] {
        var dict: [Date: Int] = [:]
        let calendar = Calendar.current
        for stat in stats {
            let startOfDay = calendar.startOfDay(for: stat.date)
            dict[startOfDay, default: 0] += stat.commits
        }
        return dict
    }
    
    // Generate dates exactly to fit the columns
    private var dateArray: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var daysCount: Int = 0
        switch dateRange {
        case .week: daysCount = 7
        case .month: daysCount = 30
        case .year: daysCount = 365
        case .allTime:
            if let minDate = stats.min(by: { $0.date < $1.date })?.date {
                let diff = calendar.dateComponents([.day], from: calendar.startOfDay(for: minDate), to: today).day ?? 365
                daysCount = max(diff + 1, 30)
            } else {
                daysCount = 365
            }
        }
        
        // Find the start date based on daysCount
        let startDate = calendar.date(byAdding: .day, value: -(daysCount - 1), to: today) ?? today
        
        // Adjust start date to the beginning of its week (Sunday=1)
        let weekday = calendar.component(.weekday, from: startDate)
        let adjustedStartDate = calendar.date(byAdding: .day, value: -(weekday - 1), to: startDate) ?? startDate
        
        var dates: [Date] = []
        var current = adjustedStartDate
        
        // Always generate full weeks until we pass 'today' and end the current week (Saturday=7)
        while current <= today {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        // Pad the end to finish the final week
        while calendar.component(.weekday, from: current) != 1 {
            dates.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        
        return dates
    }
    
    // Split dates into chunks of 7 (each chunk is a column)
    private var columns: [[Date]] {
        let dates = dateArray
        var cols: [[Date]] = []
        var index = 0
        while index < dates.count {
            let endIndex = min(index + 7, dates.count)
            let col = Array(dates[index..<endIndex])
            cols.append(col)
            index += 7
        }
        return cols
    }
    
    private func computeColor(for amount: Int, maxAmount: Int, isFuture: Bool) -> Color {
        if isFuture { return Color.clear } // Hide days past today
        if amount == 0 {
            return Color.gray.opacity(0.15)
        }
        let ratio = maxAmount > 0 ? Double(amount) / Double(maxAmount) : 0
        
        if ratio <= 0.25 {
            return Color.daEmerald.opacity(0.4)
        } else if ratio <= 0.5 {
            return Color.daEmerald.opacity(0.6)
        } else if ratio <= 0.75 {
            return Color.daEmerald.opacity(0.8)
        } else {
            return Color.daEmerald
        }
    }
    
    var body: some View {
        let maxAmount = Array(statsByDate.values).max() ?? 1
        
        VStack(alignment: .leading, spacing: 8) {
            // Header for Heatmap
            Text("stats.contributionsHeatmap".localized)
                .font(.daBodySemiBold)
                .foregroundStyle(Color.daSecondaryText)
            
            GeometryReader { geo in
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        HStack(spacing: 4) {
                            // Weekday labels
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(1...7, id: \.self) { day in
                                    if day == 2 || day == 4 || day == 6 {
                                        Text(shortWeekday(for: day))
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.daMutedText)
                                            .frame(height: 12)
                                    } else {
                                        Spacer().frame(height: 12)
                                    }
                                }
                            }
                            .padding(.trailing, 4)
                            
                            // Grid
                            HStack(spacing: 4) {
                                ForEach(0..<columns.count, id: \.self) { colIndex in
                                    let week = columns[colIndex]
                                    VStack(spacing: 4) {
                                        ForEach(week, id: \.self) { date in
                                            let amount = statsByDate[date] ?? 0
                                            let isFuture = date > Date()
                                            
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(computeColor(for: amount, maxAmount: maxAmount, isFuture: isFuture))
                                                .frame(width: 12, height: 12)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .strokeBorder(Color.black.opacity(0.05), lineWidth: isFuture ? 0 : 1)
                                                )
                                                .onHover { hover in
                                                    if hover && !isFuture {
                                                        hoveredDate = date
                                                        hoveredAmount = amount
                                                    } else if !hover && hoveredDate == date {
                                                        hoveredDate = nil
                                                    }
                                                }
                                        }
                                    }
                                    .id(colIndex) // For scrolling to the end
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 4)
                        .onAppear {
                            // Auto-scroll to the rightmost column (today)
                            if columns.count > 0 {
                                proxy.scrollTo(columns.count - 1, anchor: .trailing)
                            }
                        }
                        .onChange(of: dateRange) { _, _ in
                            if columns.count > 0 {
                                proxy.scrollTo(columns.count - 1, anchor: .trailing)
                            }
                        }
                    }
                }
            }
            .frame(height: (12 * 7) + (4 * 6) + 8) // explicitly sized
            
            Spacer()
            
            // Legend
            HStack {
                if let hoveredDate = hoveredDate {
                    HStack(spacing: 4) {
                        Text("stats.contributionsCount".localized(hoveredAmount))
                            .font(.daSmallLabel)
                            .foregroundStyle(Color.daPrimaryText)
                        Text("stats.onDate".localized(hoveredDate.formatted(.dateTime.month().day().year())))
                            .font(.daSmallLabel)
                            .foregroundStyle(Color.daMutedText)
                    }
                } else {
                    Text("stats.hoverDetails".localized)
                        .font(.daSmallLabel)
                        .foregroundStyle(Color.daMutedText)
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text("stats.less".localized)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.daMutedText)
                    
                    ForEach(0..<5) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(level == 0 ? Color.gray.opacity(0.15) : Color.daEmerald.opacity(0.25 * Double(level)))
                            .frame(width: 10, height: 10)
                    }
                    
                    Text("stats.more".localized)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.daMutedText)
                }
            }
        }
    }
    
    private func shortWeekday(for index: Int) -> String {
        switch index {
        case 2: return "stats.mon".localized
        case 4: return "stats.wed".localized
        case 6: return "stats.fri".localized
        default: return ""
        }
    }
}
