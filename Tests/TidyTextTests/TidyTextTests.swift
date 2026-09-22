import Testing
@testable import TidyText

@Suite struct TidyTextTests {
    @Test func defaultProviders() {
        let providers = AIProviderConfig.defaultProviders()
        #expect(!providers.isEmpty)
        #expect(providers.contains(where: { $0.type == .deepseek }))
        #expect(providers.contains(where: { $0.type == .doubao }))
    }

    @Test func promptTemplateRender() {
        let template = PromptTemplate(
            name: "Test",
            systemPrompt: "System",
            userPromptTemplate: "Fix: {{text}}"
        )
        let rendered = template.renderUserPrompt(text: "Hello")
        #expect(rendered == "Fix: Hello")
    }

    @Test func modelPrioritySorting() {
        let prov = AIProviderConfig(type: .deepseek)
        let m1 = ModelConfig(providerId: prov.id, modelIdentifier: "m1", displayName: "Model 1", isEnabled: true, priority: 2)
        let m2 = ModelConfig(providerId: prov.id, modelIdentifier: "m2", displayName: "Model 2", isEnabled: true, priority: 0)
        let m3 = ModelConfig(providerId: prov.id, modelIdentifier: "m3", displayName: "Model 3", isEnabled: false, priority: 1)

        let list = [m1, m2, m3].filter { $0.isEnabled }.sorted { $0.priority < $1.priority }
        #expect(list.first?.modelIdentifier == "m2")
    }
}
