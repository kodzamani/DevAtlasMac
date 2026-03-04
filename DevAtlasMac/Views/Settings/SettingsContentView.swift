import SwiftUI

struct SettingsContentView: View {
    @Bindable var languageManager: LanguageManager
    @Environment(AppViewModel.self) private var appViewModel
    @State private var showLanguagePicker = false
    @State private var showFolderPicker = false
    @State private var pendingExcludedPaths: [String] = []
    @State private var showSavedAlert = false
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 12) {
                    // App Header - Compact
                    compactAppHeader
                    
                    // About - Compact
                    compactAboutSection
                    
                    // Unified Settings Card
                    unifiedSettingsCard
                    
                    // Version Info
                    compactVersionInfo
                }
                .padding(16)
                .frame(width: min(proxy.size.width * 0.5, 720))
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.daOffWhite)
            .onAppear {
                pendingExcludedPaths = languageManager.excludedPaths
            }
            .alert("settings.exclude.saved".localized, isPresented: $showSavedAlert) {
                Button("common.ok".localized, role: .cancel) { }
            }
        }
    }
    
    // MARK: - Compact App Header
    private var compactAppHeader: some View {
        VStack(spacing: 8) {
            Image("logo_brand")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            
            Text("app.name".localized)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.daPrimaryText)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Compact About
    private var compactAboutSection: some View {
        Text("settings.about.description".localized)
            .font(.system(size: 12))
            .foregroundStyle(Color.daSecondaryText)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 8)
    }
    
    // MARK: - Unified Settings Card
    private var unifiedSettingsCard: some View {
        VStack(spacing: 16) {
            // Theme Mode - Pill Style
            settingsRow(icon: "paintbrush.fill", title: "settings.appearance.theme".localized) {
                HStack(spacing: 6) {
                    ForEach(ThemeMode.allCases) { mode in
                        themePill(mode)
                    }
                }
            }
            
            Divider()
            
            // Accent Color - Compact Grid
            settingsRow(icon: "circle.fill", title: "settings.appearance.accentColor".localized) {
                HStack(spacing: 8) {
                    ForEach(AppAccentColor.allCases) { color in
                        accentColorDot(color)
                    }
                }
            }
            
            Divider()
            
            // Language Selection
            settingsRow(icon: "globe", title: "settings.language.select".localized) {
                Button {
                    showLanguagePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text(languageManager.selectedLanguage.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.daPrimaryText)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.daMutedText)
                    }
                }
                .buttonStyle(.plain)
            }
            .sheet(isPresented: $showLanguagePicker) {
                languagePickerSheet
            }
            
            Divider()
            
            // Exclude (inline, under language)
            inlineExcludeSection
        }
        .padding(12)
        .background(Color.daWhite)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Inline Exclude Section
    private var inlineExcludeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Add Folder Button
            Button {
                showFolderPicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.minus")
                        .font(.system(size: 12))
                    
                    Text("settings.exclude.addFolder".localized)
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.daLightGray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .fileImporter(
                isPresented: $showFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        let path = url.path
                        if !pendingExcludedPaths.contains(path) {
                            pendingExcludedPaths.append(path)
                        }
                    }
                case .failure(let error):
                    print("Error selecting folder: \(error)")
                }
            }
            
            // Compact Paths List
            if !pendingExcludedPaths.isEmpty {
                VStack(spacing: 4) {
                    ForEach(pendingExcludedPaths, id: \.self) { path in
                        HStack(spacing: 6) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.daMutedText)
                            
                            Text(path)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.daPrimaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Spacer()
                            
                            Button {
                                pendingExcludedPaths.removeAll { $0 == path }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(Color.daMutedText)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.daWhite.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            } else {
                Text("settings.exclude.noPaths".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.daTertiaryText)
                    .italic()
            }
            
            // Save Button should appear whenever there are unsaved changes,
            // even if the list is now empty after removing paths.
            if languageManager.excludedPaths != pendingExcludedPaths {
                Button {
                    saveChanges()
                } label: {
                    HStack {
                        Spacer()
                        
                        Text("settings.exclude.saveChanges".localized)
                            .font(.system(size: 11, weight: .semibold))
                        
                        Spacer()
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(languageManager.accentColor.color)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Compact Version Info
    private var compactVersionInfo: some View {
        Text("settings.version".localized + " 1.0.0")
            .font(.system(size: 10))
            .foregroundStyle(Color.daTertiaryText)
    }
    
    // MARK: - Helper Views
    private func settingsRow<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(languageManager.accentColor.color)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.daSecondaryText)
            
            Spacer()
            
            content()
        }
    }
    
    private func themePill(_ mode: ThemeMode) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                languageManager.setThemeMode(mode)
                appViewModel.isDarkMode = (mode == .dark)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 10, weight: .medium))
                
                Text(mode.displayName)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(languageManager.themeMode == mode ? languageManager.accentColor.color.opacity(0.15) : Color.daLightGray.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(languageManager.themeMode == mode ? languageManager.accentColor.color : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(languageManager.themeMode == mode ? languageManager.accentColor.color : Color.daSecondaryText)
        }
        .buttonStyle(.plain)
    }
    
    private func accentColorDot(_ color: AppAccentColor) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                languageManager.setAccentColor(color)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(color.color)
                    .frame(width: 20, height: 20)
                
                Circle()
                    .strokeBorder(
                        languageManager.accentColor == color ? Color.white : Color.white.opacity(0.3),
                        lineWidth: languageManager.accentColor == color ? 2 : 1
                    )
                    .frame(width: 20, height: 20)
                
                if languageManager.accentColor == color {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func saveChanges() {
        languageManager.excludedPaths = pendingExcludedPaths
        showSavedAlert = true
        
        Task {
            await appViewModel.startScan()
        }
    }
    
    // MARK: - Language Picker Sheet
    private var languagePickerSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("settings.language.select".localized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.daPrimaryText)
                
                Spacer()
                
                Button {
                    showLanguagePicker = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.daMutedText)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .overlay(alignment: .bottom) {
                Divider()
            }
            
            // Language List
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            languageManager.setLanguage(language)
                            showLanguagePicker = false
                        } label: {
                            HStack {
                                Text(language.displayName)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.daPrimaryText)
                                
                                Spacer()
                                
                                if languageManager.selectedLanguage == language {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(languageManager.accentColor.color)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                languageManager.selectedLanguage == language
                                    ? languageManager.accentColor.color.opacity(0.08)
                                    : Color.clear
                            )
                        }
                        .buttonStyle(.plain)
                        
                        if language != AppLanguage.allCases.last {
                            Divider()
                                .padding(.leading, 12)
                        }
                    }
                }
            }
        }
        .frame(width: 260, height: 340)
        .background(Color.daWhite)
    }
}

#Preview {
    SettingsContentView(languageManager: LanguageManager())
        .environment(AppViewModel())
}
