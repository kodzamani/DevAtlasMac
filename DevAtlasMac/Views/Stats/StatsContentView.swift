import SwiftUI
import Charts

struct StatsContentView: View {
    @Bindable var viewModel: AppViewModel
    @Bindable var statsVM: StatsViewModel
    @State private var selectedProjectToAnalyze: ProjectInfo?
    @State private var codeAnalysisForPopup: CodeAnalysisResult?
    @State private var hoveredProject: String? = nil
    @State private var hoveredProjectType: String? = nil
    @State private var hoveredGitDate: Date? = nil
    @State private var hoveredGitProject: String? = nil
    @State private var hoveredFileProject: String? = nil
    @State private var searchText: String = ""
    @State private var selectedTypes: Set<String> = []
    @State private var activityFilter: ActivityLevel? = nil
    @State private var selectedGitProjects: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    
                    if statsVM.isCalculating {
                        StatsSkeletonView()
                    } else {
                        // 0. Summary Cards
                        summaryCardsSection
                        
                        // 1. Git Contributions Chart
                        gitChartSection
                        
                        // 2. Project Metrics Donut Charts
                        HStack(alignment: .top, spacing: 24) {
                            projectDonutChartSection
                            projectTypesChartSection
                        }
                        
                        // 3. Project Details and Files
                        HStack(alignment: .top, spacing: 24) {
                            projectFilesChartSection
                            projectListSection
                        }
                    }
                }
                .padding(24)
            }
            .background(Color.daOffWhite)
        }
        .task {
            // Filtered projects are already gathered by AppViewModel
            await statsVM.refreshStats(with: viewModel.filteredProjects)
        }
        .onChange(of: viewModel.filteredProjects) { _, newProjects in
            Task {
                await statsVM.refreshStats(with: newProjects)
            }
        }
        .sheet(item: $selectedProjectToAnalyze, onDismiss: {
            codeAnalysisForPopup = nil
        }) { proj in
            analyzeSheet(for: proj)
        }
    }
    
    // MARK: - Summary Cards
    private var summaryCardsSection: some View {
        HStack(spacing: 24) {
            summaryCard(
                title: "stats.projectsAnalyzed".localized,
                value: statsVM.projectMetrics.count.formatted(),
                icon: "folder.fill",
                color: Color.blue
            )
            
            summaryCard(
                title: "stats.trackedCodeLines".localized,
                value: statsVM.projectMetrics.reduce(0) { $0 + $1.value }.formatted(),
                icon: "doc.text.fill",
                color: Color.orange
            )
            
            summaryCard(
                title: "stats.gitAdditions".localized,
                value: "+\(statsVM.gitDailyStats.reduce(0) { $0 + $1.additions }.formatted())",
                icon: "plus.circle.fill",
                color: Color.green
            )
            
            summaryCard(
                title: "stats.gitDeletions".localized,
                value: "-\(statsVM.gitDailyStats.reduce(0) { $0 + $1.deletions }.formatted())",
                icon: "minus.circle.fill",
                color: Color.red
            )
        }
    }
    
    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.daBodyMedium)
                    .foregroundStyle(Color.daSecondaryText)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color.opacity(0.8))
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.daPrimaryText)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: value)
        }
        .padding(20)
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
    }
    
    // MARK: - Git Activity Chart
    private var gitChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("stats.gitActivity".localized(statsVM.dateRange.rawValue))
                    .font(.daSectionHeaderSemiBold)
                    .foregroundStyle(Color.daPrimaryText)
                
                Spacer()
                
                // Project filter dropdown
                Menu {
                    Button("stats.allProjects".localized) {
                        selectedGitProjects.removeAll()
                    }
                    
                    Divider()
                    
                    ForEach(Array(gitProjectNames), id: \.self) { projectName in
                        Button {
                            if selectedGitProjects.contains(projectName) {
                                selectedGitProjects.remove(projectName)
                            } else {
                                selectedGitProjects.insert(projectName)
                            }
                        } label: {
                            HStack {
                                Text(projectName)
                                Spacer()
                                if selectedGitProjects.contains(projectName) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(
                            selectedGitProjects.isEmpty
                            ? "stats.allProjects".localized
                            : "stats.selectedProjects".localized(selectedGitProjects.count)
                        )
                        Image(systemName: "chevron.down")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.daOffWhite)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            if statsVM.gitDailyStats.isEmpty {
                Text("stats.noGitActivity".localized)
                    .font(.daBody)
                    .foregroundStyle(Color.daMutedText)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                HStack(spacing: 24) {
                    // Left side: Bar chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("stats.activityVolume".localized)
                            .font(.daBodySemiBold)
                            .foregroundStyle(Color.daSecondaryText)
                        
                        Chart {
                            ForEach(filteredGitStats) { stat in
                                BarMark(
                                    x: .value("Date", stat.date, unit: .day),
                                    y: .value("Activity", stat.additions + stat.deletions)
                                )
                                .foregroundStyle(by: .value("Project", stat.projectName))
                                .opacity(gitBarOpacity(for: stat))
                            }
                        }
                        .chartForegroundStyleScale(domain: allProjectNames, range: allProjectColors)
                        .chartLegend(.hidden)
                        .chartYAxis {
                            AxisMarks { value in
                                AxisGridLine()
                                AxisTick()
                                if let count = value.as(Int.self) {
                                    AxisValueLabel {
                                        Text("\(count)")
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day, count: max(1, statsVM.gitDailyStats.count / 10))) { value in
                                AxisGridLine()
                                AxisTick()
                                if value.as(Date.self) != nil {
                                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                                }
                            }
                        }
                        .chartOverlay { chartProxy in
                            GeometryReader { geometry in
                                Rectangle()
                                    .fill(Color.clear)
                                    .contentShape(Rectangle())
                                    .onContinuousHover { phase in
                                        switch phase {
                                        case .active(let location):
                                            updateHoveredGitStat(at: location, chartProxy: chartProxy, geometry: geometry)
                                        case .ended:
                                            clearHoveredGitStat()
                                        }
                                    }
                                    .onTapGesture {
                                        clearHoveredGitStat()
                                    }
                            }
                        }
                        .overlay(
                            Group {
                                if let hoveredDate = hoveredGitDate,
                                   let stat = hoveredGitStat {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(stat.projectName)
                                            .font(.daBodySemiBold)
                                            .lineLimit(1)
                                        Text(hoveredDate, format: .dateTime.month().day().year())
                                            .font(.daSmallLabel)
                                        HStack(spacing: 8) {
                                            Text("+\(stat.additions.formatted())")
                                                .foregroundColor(.green)
                                                .font(.daSmallLabel)
                                            Text("-\(stat.deletions.formatted())")
                                                .foregroundColor(.red)
                                                .font(.daSmallLabel)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color.daWhite)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                                }
                            }
                            .padding()
                        )
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Right side: Heatmap
                    GitHeatmapView(stats: filteredGitStats, dateRange: statsVM.dateRange)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 250)
                
                // Custom wrapping legend below the charts
                if !filteredGitStats.isEmpty {
                    FlowLayout(spacing: 12) {
                        ForEach(gitProjectNames, id: \.self) { proj in
                            if selectedGitProjects.isEmpty || selectedGitProjects.contains(proj) {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(color(forProject: proj))
                                        .frame(width: 8, height: 8)
                                    Text(proj)
                                        .font(.daSmallLabel)
                                        .foregroundStyle(Color.daSecondaryText)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                    .padding(.top, 16)
                }
            }
        }
        .padding(20)
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
    }
    
    // Helper function to check if a Git stat is being hovered
    private func isGitStatHovered(_ stat: GitDailyStat) -> Bool {
        guard let hoveredGitDate = hoveredGitDate else { return false }
        let isSameDay = Calendar.current.isDate(stat.date, inSameDayAs: hoveredGitDate)
        if let hoveredGitProject = hoveredGitProject {
            return isSameDay && hoveredGitProject == stat.projectName
        }
        return isSameDay
    }

    private func gitBarOpacity(for stat: GitDailyStat) -> Double {
        guard hoveredGitDate != nil else { return 0.8 }
        return isGitStatHovered(stat) ? 1.0 : 0.3
    }

    private var hoveredGitStat: GitDailyStat? {
        guard let hoveredGitDate, let hoveredGitProject else { return nil }
        return filteredGitStats.first {
            Calendar.current.isDate($0.date, inSameDayAs: hoveredGitDate) && $0.projectName == hoveredGitProject
        }
    }

    private func clearHoveredGitStat() {
        hoveredGitDate = nil
        hoveredGitProject = nil
    }

    private func updateHoveredGitStat(at location: CGPoint, chartProxy: ChartProxy, geometry: GeometryProxy) {
        guard let plotFrame = chartProxy.plotFrame else {
            clearHoveredGitStat()
            return
        }
        
        let plotRect = geometry[plotFrame]
        guard plotRect.contains(location) else {
            clearHoveredGitStat()
            return
        }
        
        let localX = location.x - plotRect.origin.x
        let localY = location.y - plotRect.origin.y
        
        guard let rawDate = chartProxy.value(atX: localX, as: Date.self),
              let yValue = chartProxy.value(atY: localY, as: Double.self) else {
            clearHoveredGitStat()
            return
        }
        
        let calendar = Calendar.current
        let hoveredDay = calendar.startOfDay(for: rawDate)
        let dayStats = filteredGitStats
            .filter { calendar.isDate($0.date, inSameDayAs: hoveredDay) }
            .sorted { left, right in
                projectSortIndex(for: left.projectName) < projectSortIndex(for: right.projectName)
            }
        
        guard !dayStats.isEmpty else {
            clearHoveredGitStat()
            return
        }
        
        hoveredGitDate = hoveredDay
        hoveredGitProject = hoveredGitProjectName(for: yValue, in: dayStats)
    }

    private func hoveredGitProjectName(for yValue: Double, in dayStats: [GitDailyStat]) -> String? {
        var cumulative = 0.0
        let target = max(0, yValue)
        
        for stat in dayStats {
            cumulative += Double(stat.totalChanges)
            if target <= cumulative {
                return stat.projectName
            }
        }
        
        return dayStats.last?.projectName
    }

    private func projectSortIndex(for name: String) -> Int {
        allProjectNames.firstIndex(of: name) ?? .max
    }

    private func metricName(
        at location: CGPoint,
        in metrics: [ProjectMetric],
        chartProxy: ChartProxy,
        geometry: GeometryProxy
    ) -> String? {
        guard !metrics.isEmpty, let plotFrame = chartProxy.plotFrame else { return nil }
        
        let plotRect = geometry[plotFrame]
        guard plotRect.contains(location) else { return nil }
        
        let center = CGPoint(x: plotRect.midX, y: plotRect.midY)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt((dx * dx) + (dy * dy))
        let outerRadius = min(plotRect.width, plotRect.height) / 2
        let innerRadius = outerRadius * 0.6
        
        guard distance >= innerRadius, distance <= outerRadius else { return nil }
        
        var angle = atan2(dx, -dy)
        if angle < 0 {
            angle += (.pi * 2)
        }
        
        let total = metrics.reduce(0) { $0 + $1.value }
        guard total > 0 else { return nil }
        
        let selectedValue = (angle / (.pi * 2)) * Double(total)
        var cumulative = 0.0
        
        for metric in metrics {
            cumulative += Double(metric.value)
            if selectedValue <= cumulative {
                return metric.projectName
            }
        }
        
        return metrics.last?.projectName
    }

    private func fileMetricName(
        at location: CGPoint,
        chartProxy: ChartProxy,
        geometry: GeometryProxy
    ) -> String? {
        guard let plotFrame = chartProxy.plotFrame else { return nil }
        
        let plotRect = geometry[plotFrame]
        guard plotRect.contains(location) else { return nil }
        
        let localY = location.y - plotRect.origin.y
        return chartProxy.value(atY: localY, as: String.self)
    }
    
    // Get unique project names from git stats
    private var gitProjectNames: [String] {
        Array(Set(statsVM.gitDailyStats.map(\.projectName))).sorted()
    }
    
    // Filter git stats based on selected projects
    private var filteredGitStats: [GitDailyStat] {
        if selectedGitProjects.isEmpty {
            return statsVM.gitDailyStats
        } else {
            return statsVM.gitDailyStats.filter { selectedGitProjects.contains($0.projectName) }
        }
    }
    
    // MARK: - Consistent Colors
    private var allProjectNames: [String] {
        Array(Set(statsVM.projectMetrics.map(\.projectName) + statsVM.gitDailyStats.map(\.projectName))).sorted()
    }
    
    private var allProjectColors: [Color] {
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .red, .cyan, .teal, .pink, .yellow, .indigo, .mint, .brown,
            Color(red: 0.2, green: 0.6, blue: 0.8), Color(red: 0.8, green: 0.4, blue: 0.2), Color(red: 0.5, green: 0.2, blue: 0.7)
        ]
        if allProjectNames.isEmpty { return [] }
        return allProjectNames.enumerated().map { index, _ in colors[index % colors.count] }
    }
    
    private func color(forProject projectName: String) -> Color {
        guard let index = allProjectNames.firstIndex(of: projectName) else { return .gray }
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .red, .cyan, .teal, .pink, .yellow, .indigo, .mint, .brown,
            Color(red: 0.2, green: 0.6, blue: 0.8), Color(red: 0.8, green: 0.4, blue: 0.2), Color(red: 0.5, green: 0.2, blue: 0.7)
        ]
        return colors[index % colors.count]
    }
    
    private var allProjectTypes: [String] {
        Array(Set(statsVM.projectTypeMetrics.map(\.projectName))).sorted()
    }
    
    private var allProjectTypeColors: [Color] {
        let colors: [Color] = [
            .indigo, .mint, .brown, .blue, .green, .orange, .purple, .red, .cyan, .teal, .pink, .yellow,
            Color(red: 0.5, green: 0.2, blue: 0.7), Color(red: 0.2, green: 0.6, blue: 0.8), Color(red: 0.8, green: 0.4, blue: 0.2)
        ]
        if allProjectTypes.isEmpty { return [] }
        return allProjectTypes.enumerated().map { index, _ in colors[index % colors.count] }
    }
    
    private func color(forProjectType typeName: String) -> Color {
        guard let index = allProjectTypes.firstIndex(of: typeName) else { return .gray }
        let colors: [Color] = [
            .indigo, .mint, .brown, .blue, .green, .orange, .purple, .red, .cyan, .teal, .pink, .yellow,
            Color(red: 0.5, green: 0.2, blue: 0.7), Color(red: 0.2, green: 0.6, blue: 0.8), Color(red: 0.8, green: 0.4, blue: 0.2)
        ]
        return colors[index % colors.count]
    }
    
    // MARK: - Project Loc Donut Chart
    private var projectDonutChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("stats.codeLinesByProject".localized)
                .font(.daSectionHeaderSemiBold)
                .foregroundStyle(Color.daPrimaryText)
            
            if statsVM.projectMetrics.isEmpty {
                Text("stats.noCodeLines".localized)
                    .font(.daBody)
                    .foregroundStyle(Color.daMutedText)
                    .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                Chart(statsVM.projectMetrics) { item in
                    SectorMark(
                        angle: .value("Lines", item.value),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Project", item.projectName))
                    .opacity(hoveredProject == nil || hoveredProject == item.projectName ? 1.0 : 0.3)
                }
                .chartForegroundStyleScale(domain: allProjectNames, range: allProjectColors)
                .chartLegend(.hidden)
                .frame(height: 300)
                .chartOverlay { chartProxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    hoveredProject = metricName(
                                        at: location,
                                        in: statsVM.projectMetrics,
                                        chartProxy: chartProxy,
                                        geometry: geometry
                                    )
                                case .ended:
                                    hoveredProject = nil
                                }
                            }
                    }
                }
                .overlay(
                    Group {
                        if let hoveredProject = hoveredProject,
                           let metric = statsVM.projectMetrics.first(where: { $0.projectName == hoveredProject }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(metric.projectName)
                                    .font(.daBodySemiBold)
                                    .lineLimit(1)
                                Text("stats.linesValue".localized(metric.value.formatted()))
                                    .font(.daSmallLabel)
                                Text("\(String(format: "%.1f", (Double(metric.value) / Double(statsVM.projectMetrics.reduce(0) { $0 + $1.value }) * 100)))%")
                                    .font(.daSmallLabel)
                            }
                            .padding(8)
                            .background(Color.daWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        }
                    }
                        .padding()
                )
                
                // Custom wrapping legend
                FlowLayout(spacing: 12) {
                    ForEach(statsVM.projectMetrics.prefix(15), id: \.projectName) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color(forProject: item.projectName))
                                .frame(width: 8, height: 8)
                            Text(item.projectName)
                                .font(.daSmallLabel)
                                .foregroundStyle(Color.daSecondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.top, 16)
            }
        }
        .padding(20)
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Detailed List Section
    private var projectListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("stats.allProjects".localized)
                .font(.daSectionHeaderSemiBold)
                .foregroundStyle(Color.daPrimaryText)
            
            if statsVM.projectMetrics.isEmpty {
                Text("stats.noProjectsToRank".localized)
                    .font(.daBody)
                    .foregroundStyle(Color.daMutedText)
                    .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("search.projects".localized, text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.daOffWhite)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Type filters
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(Array(statsVM.projectTypeMetrics.map(\.projectName)), id: \.self) { type in
                            Button {
                                if selectedTypes.contains(type) {
                                    selectedTypes.remove(type)
                                } else {
                                    selectedTypes.insert(type)
                                }
                            } label: {
                                Text(type)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedTypes.contains(type) ? Color.daBlue : Color.daOffWhite)
                                    .foregroundStyle(selectedTypes.contains(type) ? Color.daWhite : Color.daPrimaryText)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // Project list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(Array(filteredProjects.enumerated()), id: \.element.id) { index, metric in
                            Button {
                                if let proj = statsVM.getProject(named: metric.projectName) {
                                    codeAnalysisForPopup = nil
                                    selectedProjectToAnalyze = proj
                                }
                            } label: {
                                HStack {
                                    Text("\(index + 1).")
                                        .font(.daBodySemiBold)
                                        .foregroundStyle(Color.daMutedText)
                                        .frame(width: 24, alignment: .leading)
                                    
                                    VStack(alignment: .leading) {
                                        Text(metric.projectName)
                                            .font(.daBodyMedium)
                                            .foregroundStyle(Color.daPrimaryText)
                                            .lineLimit(1)
                                        
                                        HStack {
                                            Text(metric.projectType)
                                                .font(.daSmallLabel)
                                                .foregroundStyle(Color.daSecondaryText)
                                            
                                            ActivityIndicator(level: statsVM.getActivityLevel(for: metric.projectName))
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing) {
                                        Text("stats.codeLinesValue".localized(metric.value.formatted()))
                                            .font(.daBodyMedium)
                                            .foregroundStyle(Color.daPrimaryText)
                                        
                                        if let lastCommit = statsVM.getLastCommitDate(for: metric.projectName) {
                                            Text(lastCommit, format: .relative(presentation: .named))
                                                .font(.daSmallLabel)
                                                .foregroundStyle(Color.daMutedText)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            if index < filteredProjects.count - 1 {
                                Divider().foregroundStyle(Color.daBorder)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
        .frame(minWidth: 350)
        .frame(height: 500)
    }
    
    // Filter projects based on search text and filters
    private var filteredProjects: [ProjectMetric] {
        var filtered = statsVM.projectMetrics
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.projectName.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Filter by type
        if !selectedTypes.isEmpty {
            filtered = filtered.filter { selectedTypes.contains($0.projectType) }
        }
        
        // Filter by activity level
        if let activityFilter = activityFilter {
            filtered = filtered.filter { statsVM.getActivityLevel(for: $0.projectName) == activityFilter }
        }
        
        return filtered
    }
    // MARK: - Project Types Donut Chart
    private var projectTypesChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("stats.projectTypes".localized)
                .font(.daSectionHeaderSemiBold)
                .foregroundStyle(Color.daPrimaryText)
            
            if statsVM.projectTypeMetrics.isEmpty {
                Text("stats.noData".localized)
                    .font(.daBody)
                    .foregroundStyle(Color.daMutedText)
                    .frame(maxWidth: .infinity, minHeight: 250)
            } else {
                Chart(statsVM.projectTypeMetrics) { item in
                    SectorMark(
                        angle: .value("Count", item.value),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Type", item.projectName))
                    .opacity(hoveredProjectType == nil || hoveredProjectType == item.projectName ? 1.0 : 0.3)
                }
                .chartForegroundStyleScale(domain: allProjectTypes, range: allProjectTypeColors)
                .chartLegend(.hidden)
                .frame(height: 300)
                .chartOverlay { chartProxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    hoveredProjectType = metricName(
                                        at: location,
                                        in: statsVM.projectTypeMetrics,
                                        chartProxy: chartProxy,
                                        geometry: geometry
                                    )
                                case .ended:
                                    hoveredProjectType = nil
                                }
                            }
                    }
                }
                .overlay(
                    Group {
                        if let hoveredProjectType = hoveredProjectType,
                           let metric = statsVM.projectTypeMetrics.first(where: { $0.projectName == hoveredProjectType }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(metric.projectName)
                                    .font(.daBodySemiBold)
                                Text("stats.projectTypeCount".localized(metric.value.formatted()))
                                    .font(.daSmallLabel)
                                Text("\(String(format: "%.1f", (Double(metric.value) / Double(statsVM.projectTypeMetrics.reduce(0) { $0 + $1.value }) * 100)))%")
                                    .font(.daSmallLabel)
                            }
                            .padding(8)
                            .background(Color.daWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                        }
                    }
                        .padding()
                )
                
                // Custom wrapping legend
                FlowLayout(spacing: 12) {
                    ForEach(statsVM.projectTypeMetrics, id: \.projectName) { item in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(color(forProjectType: item.projectName))
                                .frame(width: 8, height: 8)
                            Text(item.projectName)
                                .font(.daSmallLabel)
                                .foregroundStyle(Color.daSecondaryText)
                                .lineLimit(1)
                        }
                    }
                }
                .padding(.top, 16)
            }
        }
        .padding(20)
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Project Files Bar Chart
    private var projectFilesChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("stats.topProjectsByFileCount".localized)
                .font(.daSectionHeaderSemiBold)
                .foregroundStyle(Color.daPrimaryText)
            
            if statsVM.projectFileMetrics.isEmpty {
                Text("stats.noData".localized)
                    .font(.daBody)
                    .foregroundStyle(Color.daMutedText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical) {
                    Chart(statsVM.projectFileMetrics) { item in
                        BarMark(
                            x: .value("Files", item.value),
                            y: .value("Project", item.projectName)
                        )
                        .foregroundStyle(Color.daEmerald.opacity(0.8))
                        .opacity(hoveredFileProject == nil || hoveredFileProject == item.projectName ? 1.0 : 0.35)
                        .annotation(position: .trailing) {
                            Text("\(item.value.formatted())")
                                .font(.daSmallLabel)
                                .foregroundStyle(Color.daSecondaryText)
                        }
                    }
                    .frame(height: max(300, CGFloat(statsVM.projectFileMetrics.count * 40)))
                    .padding(.trailing, 30)
                    .chartOverlay { chartProxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        hoveredFileProject = fileMetricName(
                                            at: location,
                                            chartProxy: chartProxy,
                                            geometry: geometry
                                        )
                                    case .ended:
                                        hoveredFileProject = nil
                                    }
                                }
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if let hoveredFileProject = hoveredFileProject,
                           let metric = statsVM.projectFileMetrics.first(where: { $0.projectName == hoveredFileProject }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(metric.projectName)
                                    .font(.daBodySemiBold)
                                    .lineLimit(1)
                                Text("\(metric.value.formatted()) files")
                                    .font(.daSmallLabel)
                            }
                            .padding(8)
                            .background(Color.daWhite)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            .padding(12)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
        .frame(maxWidth: .infinity)
        .frame(height: 500)
    }
    
    // MARK: - Analyze Sheet
    private func analyzeSheet(for proj: ProjectInfo) -> some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.daEmerald)
                    Text("stats.projectsAnalyze".localized)
                        .font(.daSectionTitle)
                        .foregroundStyle(Color.daPrimaryText)
                }
                Spacer()
                Text(proj.name)
                    .font(.daBody)
                    .foregroundStyle(Color.daMutedText)
                Button {
                    selectedProjectToAnalyze = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.daMutedText)
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.daWhite)

            Divider()
                .foregroundStyle(Color.daBorder)

            if let analysis = codeAnalysisForPopup {
                if analysis.totalFiles > 0 {
                    ScrollView {
                        ProjectAnalyzeView(analysis: analysis, projectPath: proj.path, runner: viewModel.runner)
                            .padding(20)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundStyle(Color.daMutedText)
                        Text("stats.noSourceFiles".localized)
                            .font(.daBody)
                            .foregroundStyle(Color.daMutedText)
                    }
                    Spacer()
                }
            } else {
                Spacer()
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("stats.analyzingProject".localized)
                        .font(.daBody)
                        .foregroundStyle(Color.daMutedText)
                }
                Spacer()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .frame(idealWidth: 900, idealHeight: 700)
        .background(Color.daOffWhite)
        .task(id: proj.id) {
            codeAnalysisForPopup = await CodeAnalyzer.analyze(for: proj)
        }
    }
    
    // MARK: - Skeleton Loading View
    struct StatsSkeletonView: View {
        @State private var isAnimating = false
        
        var body: some View {
            VStack(spacing: 24) {
                // Summary Cards
                HStack(spacing: 24) {
                    ForEach(0..<4, id: \.self) { _ in
                        skeletonSummaryCard
                    }
                }
                
                // Git Chart
                skeletonCard(height: 330)
                
                // Donut Charts
                HStack(alignment: .top, spacing: 24) {
                    skeletonCard(height: 380)
                    skeletonCard(height: 380)
                }
                
                // Details & Files
                HStack(alignment: .top, spacing: 24) {
                    skeletonCard(height: 500)
                    skeletonCard(height: 500)
                }
            }
            .onAppear {
                isAnimating = true
            }
        }
        
        private var skeletonSummaryCard: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(isAnimating ? 0.1 : 0.2))
                        .frame(width: 100, height: 16)
                    Spacer()
                    Circle()
                        .fill(Color.gray.opacity(isAnimating ? 0.1 : 0.2))
                        .frame(width: 16, height: 16)
                }
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(isAnimating ? 0.1 : 0.2))
                    .frame(width: 80, height: 28)
            }
            .padding(20)
            .background(Color.daWhite)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isAnimating)
        }
        
        private func skeletonCard(height: CGFloat) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(isAnimating ? 0.1 : 0.2))
                        .frame(width: 150, height: 20)
                    Spacer()
                }
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(isAnimating ? 0.05 : 0.1))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(20)
            .frame(height: height)
            .background(Color.daWhite)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.03), radius: 5, y: 2)
            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: isAnimating)
        }
    }
}

