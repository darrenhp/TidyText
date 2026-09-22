import Foundation
import Combine

public struct HistoryItem: Identifiable, Codable, Equatable {
    public var id: UUID
    public var timestamp: Date
    public var originalText: String
    public var replacedText: String
    public var promptName: String
    public var modelName: String
    public var providerName: String
    public var isSuccess: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        originalText: String,
        replacedText: String,
        promptName: String,
        modelName: String,
        providerName: String,
        isSuccess: Bool = true
    ) {
        self.id = id
        self.timestamp = timestamp
        self.originalText = originalText
        self.replacedText = replacedText
        self.promptName = promptName
        self.modelName = modelName
        self.providerName = providerName
        self.isSuccess = isSuccess
    }
}

public final class HistoryManager: ObservableObject {
    public static let shared = HistoryManager()

    @Published public var items: [HistoryItem] = []
    private let maxItems: Int = 30

    private init() {}

    public func add(
        originalText: String,
        replacedText: String,
        promptName: String,
        modelName: String,
        providerName: String,
        isSuccess: Bool = true
    ) {
        let item = HistoryItem(
            originalText: originalText,
            replacedText: replacedText,
            promptName: promptName,
            modelName: modelName,
            providerName: providerName,
            isSuccess: isSuccess
        )
        DispatchQueue.main.async {
            self.items.insert(item, at: 0)
            if self.items.count > self.maxItems {
                self.items.removeLast(self.items.count - self.maxItems)
            }
        }
    }

    public func clear() {
        DispatchQueue.main.async {
            self.items.removeAll()
        }
    }

    public func restoreOriginal(for item: HistoryItem) async {
        await TextReplaceService.shared.replaceSelectedText(with: item.originalText)
    }
}
