import SwiftUI

// MARK: - Collapsible Dependencies Section View

/// UI component to display project dependencies in a collapsible section
struct CollapsibleDependenciesSectionView: View {
    let project: ProjectInfo
    let dependencies: ProjectDependencies?
    @State private var isExpanded: Bool = false
    
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 7) {
                // Header
                headerView
                
                // Conditional content based on expanded state
                if isExpanded {
                    expandedContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                } else {
                    collapsedContent
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top))
                        ))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color.daWhite)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.daBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(duration: 0.3), value: isExpanded)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 8) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.daBlue)
            
            Text(project.name)
                .font(.daSubSectionSemiBold)
                .foregroundStyle(Color.daPrimaryText)
            
            Spacer()
            
            if let deps = dependencies {
                Text("\(deps.totalCount)")
                    .font(.daSmallLabel)
                    .foregroundStyle(Color.daMutedText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.daLightGray)
                    .clipShape(Capsule())
            }
            
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.daMutedText)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
    }
    
    // MARK: - Collapsed Content
    
    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let deps = dependencies {
                if deps.hasDependencies {
                    if deps.projectGroups.isEmpty {
                        Text("projects.collapsedDependencies"
                            .localized(with: deps.totalCount))
                            .font(.daBody)
                            .foregroundStyle(Color.daSecondaryText)
                            .padding(.top, 4)
                    } else {
                        Text("projects.collapsedDependenciesMultiProject"
                            .localized(with: deps.totalCount, deps.projectGroups.count))
                            .font(.daBody)
                            .foregroundStyle(Color.daSecondaryText)
                            .padding(.top, 4)
                    }
                } else {
                    Text("projects.noDependencies".localized)
                        .font(.daBody)
                        .foregroundStyle(Color.daMutedText)
                        .padding(.top, 4)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("projects.loadingDependencies".localized)
                        .font(.daBody)
                        .foregroundStyle(Color.daMutedText)
                }
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Expanded Content
    
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let deps = dependencies {
                if deps.hasDependencies {
                    // Show project groups for .NET solutions
                    if !deps.projectGroups.isEmpty {
                        projectGroupsSection
                    }
                    
                    // Show regular dependencies
                    if !deps.directDependencies.isEmpty {
                        dependencyTable(
                            title: "projects.dependencies".localized,
                            dependencies: deps.directDependencies,
                            color: Color.daBlue
                        )
                    }
                    
                    // Show dev dependencies
                    if !deps.devDependencies.isEmpty {
                        dependencyTable(
                            title: "projects.devDependencies".localized,
                            dependencies: deps.devDependencies,
                            color: Color.purple
                        )
                    }
                } else {
                    Text("projects.noDependencies".localized)
                        .font(.daBody)
                        .foregroundStyle(Color.daMutedText)
                        .padding(.vertical, 8)
                }
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("projects.loadingDependencies".localized)
                        .font(.daBody)
                        .foregroundStyle(Color.daMutedText)
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Project Groups (.NET)
    
    private var projectGroupsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(dependencies?.projectGroups ?? []) { group in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.daOrange)
                        
                        Text(group.projectName)
                            .font(.daBodyMedium)
                            .foregroundStyle(Color.daSecondaryText)
                        
                        Text("(\(group.dependencyCount))")
                            .font(.daSmallLabel)
                            .foregroundStyle(Color.daMutedText)
                    }
                    
                    dependencyTable(
                        title: nil,
                        dependencies: group.dependencies,
                        color: Color.daOrange
                    )
                }
                .padding(.vertical, 4)
                
                if group.id != dependencies?.projectGroups.last?.id {
                    Divider()
                        .padding(.vertical, 2)
                }
            }
        }
    }
    
    // MARK: - Dependency Table
    
    private func dependencyTable(title: String?, dependencies: [Dependency], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                    
                    Text(title)
                        .font(.daBodyMedium)
                        .foregroundStyle(Color.daSecondaryText)
                    
                    Text("(\(dependencies.count))")
                        .font(.daSmallLabel)
                        .foregroundStyle(Color.daMutedText)
                }
            }
            
            // Table Header
            tableHeader
            
            // Table Body
            VStack(spacing: 0) {
                ForEach(Array(dependencies.enumerated()), id: \.element.id) { index, dep in
                    tableRow(dependency: dep, isEven: index % 2 == 0)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.daBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 4)
    }
    
    private var tableHeader: some View {
        HStack(spacing: 0) {
            Text("Package")
                .font(.daSmallLabel)
                .foregroundStyle(Color.daMutedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Divider()
                .frame(height: 16)
            
            Text("Version")
                .font(.daSmallLabel)
                .foregroundStyle(Color.daMutedText)
                .frame(width: 160, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            
            Divider()
                .frame(height: 16)
            
            Text("Source")
                .font(.daSmallLabel)
                .foregroundStyle(Color.daMutedText)
                .frame(width: 80, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(Color.daLightGray.opacity(0.5))
    }
    
    private func tableRow(dependency: Dependency, isEven: Bool) -> some View {
        HStack(spacing: 0) {
            // Package Name
            HStack(spacing: 6) {
                Circle()
                    .fill(typeColor(dependency.type))
                    .frame(width: 6, height: 6)
                
                Text(dependency.name)
                    .font(.daTechTag)
                    .foregroundStyle(Color.daDarkBlue)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
                .frame(height: 20)
            
            // Version
            Group {
                if dependency.isUpgradeable, let latest = dependency.latestVersion {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text(dependency.displayVersion)
                                .font(.daSmallLabel)
                                .foregroundStyle(Color.daSecondaryText)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Color.orange)
                            Text(latest)
                                .font(.daSmallLabel)
                                .foregroundStyle(Color.orange)
                        }
                        Text("dependency.upgradeable".localized)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                    }
                } else {
                    Text(dependency.displayVersion)
                        .font(.daSmallLabel)
                        .foregroundStyle(Color.daSecondaryText)
                }
            }
            .frame(width: 160, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
                .frame(height: 20)
            
            // Source
            HStack(spacing: 4) {
                sourceIcon(for: dependency.source)
                Text(dependency.source.displayName)
                    .font(.daSmallLabel)
                    .foregroundStyle(Color.daMutedText)
            }
            .frame(width: 80, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(isEven ? Color.daWhite : Color.daLightGray.opacity(0.3))
    }
    
    private func typeColor(_ type: DependencyType) -> Color {
        switch type {
        case .regular:
            return Color.daBlue
        case .dev:
            return Color.purple
        case .peer:
            return Color.orange
        case .optional:
            return Color.gray
        case .transitive:
            return Color.daMutedText
        }
    }
    
    @ViewBuilder
    private func sourceIcon(for source: DependencySource) -> some View {
        switch source {
        case .npm:
            Image("npm")
                .resizable()
                .frame(width: 15, height: 15)
        case .yarn:
            Image(systemName: "yarn")
                .font(.system(size: 10))
                .foregroundStyle(Color.blue)
        case .pnpm:
            Image(systemName: "pnpm")
                .font(.system(size: 10))
                .foregroundStyle(Color.yellow)
        case .pub:
            Image(systemName: "pub")
                .font(.system(size: 10))
                .foregroundStyle(Color.blue)
        case .cargo:
            Image(systemName: "shippingbox")
                .font(.system(size: 10))
                .foregroundStyle(Color.orange)
        case .go:
            Image("go")
                .resizable()
                .frame(width: 15, height: 15)
        case .nuget:
            Image("nuget")
                .resizable()
                .frame(width: 15, height: 15)
        case .spm:
            Image(systemName: "swift")
                .font(.system(size: 10))
                .foregroundStyle(Color.orange)
        case .cocoapods:
            Image(systemName: "p.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.gray)
        case .carthage:
            Image(systemName: "c.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.black)
        }
    }
}

// MARK: - Localization Extension

extension String {
    func localized(with arguments: CVarArg...) -> String {
        let localized = NSLocalizedString(self, comment: "")
        return String(format: localized, arguments: arguments)
    }
}
