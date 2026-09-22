import Foundation
import AppKit

public final class TidyPipeline {
    public static let shared = TidyPipeline()

    private var isBusy: Bool = false

    private init() {}

    public func triggerTidy() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        // 1. Accessibility check
        if !PermissionsManager.shared.isAccessibilityTrusted {
            PermissionsManager.shared.checkAndRequestAccessibility()
            await MainActor.run {
                CursorHUDController.shared.show(status: .error("请在系统设置中授予辅助功能权限"))
            }
            return
        }

        await MainActor.run {
            CursorHUDController.shared.show(status: .loading("✦ 正在读取选区..."))
        }

        // 2. Capture selected text
        guard let originalText = await TextCaptureService.shared.captureSelectedText(),
              !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            await MainActor.run {
                CursorHUDController.shared.show(status: .error("未检测到选中文本，请先划选一段文字"))
            }
            return
        }

        // 3. Get active prompt
        let prompt = ConfigStorage.shared.getActivePrompt()

        // 4. Execute AI via priority model router
        do {
            let result = try await ModelRouter.shared.executeTidy(
                prompt: prompt,
                text: originalText,
                configStorage: .shared,
                onStatusUpdate: { status in
                    Task { @MainActor in
                        if status.contains("重试") {
                            CursorHUDController.shared.show(status: .retrying(status))
                        } else {
                            CursorHUDController.shared.show(status: .loading(status))
                        }
                    }
                }
            )

            // 5. In-place replace
            let success = await TextReplaceService.shared.replaceSelectedText(with: result.resultText)

            // 6. Record to history snapshot
            HistoryManager.shared.add(
                originalText: originalText,
                replacedText: result.resultText,
                promptName: prompt.name,
                modelName: result.model.displayName,
                providerName: result.provider.name,
                isSuccess: success
            )

            // 7. Optional haptic / sound feedback
            if ConfigStorage.shared.preferences.playFeedbackSound {
                NSSound(named: "Pop")?.play()
            }

            await MainActor.run {
                CursorHUDController.shared.show(status: .success("✓ 已由 \(result.model.displayName) 原位替换"))
            }
        } catch {
            await MainActor.run {
                CursorHUDController.shared.show(status: .error(error.localizedDescription))
            }
        }
    }
}
