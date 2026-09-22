import Foundation
import AppKit
import SwiftUI

public enum HUDStatus: Equatable {
    case idle
    case loading(String)
    case retrying(String)
    case success(String)
    case error(String)
}

@MainActor
public final class CursorHUDController: ObservableObject {
    public static let shared = CursorHUDController()

    @Published public var currentStatus: HUDStatus = .idle

    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    @MainActor
    public func show(status: HUDStatus) {
        self.currentStatus = status
        dismissWorkItem?.cancel()

        if panel == nil {
            createPanel()
        }

        updatePosition()
        panel?.orderFrontRegardless()

        switch status {
        case .success:
            scheduleDismiss(after: 0.9)
        case .error:
            scheduleDismiss(after: 3.5)
        default:
            break
        }
    }

    @MainActor
    public func dismiss() {
        dismissWorkItem?.cancel()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.panel?.orderOut(nil)
                self?.panel?.alphaValue = 1
                self?.currentStatus = .idle
            }
        })
    }

    private func scheduleDismiss(after seconds: Double) {
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.dismiss()
            }
        }
        dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    @MainActor
    private func createPanel() {
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 42),
            styleMask: [.borderless, .nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.level = .floating
        p.hasShadow = true
        p.isMovableByWindowBackground = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: CursorHUDView(controller: self))
        p.contentView = hostingView
        self.panel = p
    }

    @MainActor
    private func updatePosition() {
        guard let panel = panel else { return }

        // Position near mouse cursor
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSPointInRect(mouseLoc, $0.frame) }) ?? NSScreen.main

        let panelSize = CGSize(width: 240, height: 44)
        var origin = CGPoint(x: mouseLoc.x + 15, y: mouseLoc.y - panelSize.height - 15)

        if let screen = screen {
            let visibleFrame = screen.visibleFrame
            if origin.x + panelSize.width > visibleFrame.maxX {
                origin.x = visibleFrame.maxX - panelSize.width - 10
            }
            if origin.x < visibleFrame.minX {
                origin.x = visibleFrame.minX + 10
            }
            if origin.y < visibleFrame.minY {
                origin.y = mouseLoc.y + 20
            }
            if origin.y + panelSize.height > visibleFrame.maxY {
                origin.y = visibleFrame.maxY - panelSize.height - 10
            }
        }

        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)
    }
}

public struct CursorHUDView: View {
    @ObservedObject var controller: CursorHUDController

    public var body: some View {
        HStack(spacing: 8) {
            switch controller.currentStatus {
            case .idle:
                EmptyView()
            case .loading(let msg):
                ProgressView()
                    .controlSize(.small)
                Text(msg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            case .retrying(let msg):
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                Text(msg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.orange)
                    .lineLimit(1)
            case .success(let msg):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.green)
                Text(msg)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            case .error(let msg):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.red)
                Text(msg)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }
}
