import SwiftUI

struct AIPromptsContentView: View {
    private let promptGridColumns = [
        GridItem(.flexible(), spacing: 20, alignment: .top),
        GridItem(.flexible(), spacing: 20, alignment: .top)
    ]
    
    private let promptCategories = AIPromptLibrary.categories

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                
                ForEach(promptCategories) { category in
                    categorySection(title: category.title, icon: category.icon, prompts: category.prompts)
                }
            }
            .padding(24)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("aiprompts.title".localized)
                        .font(.system(size: 28, weight: .bold))
                    
                    Text(String(format: "aiprompts.subtitle".localized, promptCategories.count, promptCategories.flatMap(\.prompts).count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text("aiprompts.description".localized)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Divider()
                .padding(.top, 8)
        }
    }
    
    private func categorySection(title: String, icon: String, prompts: [AIPromptTemplate]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.title2.bold())
            }
            
            LazyVGrid(columns: promptGridColumns, alignment: .leading, spacing: 20) {
                ForEach(prompts) { promptItem in
                    PromptCard(
                        title: promptItem.title,
                        description: promptItem.description,
                        prompt: promptItem.prompt
                    )
                }
            }
        }
    }
}


#Preview {
    AIPromptsContentView()
}
