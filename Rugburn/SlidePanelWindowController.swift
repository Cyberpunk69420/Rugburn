import AppKit
import SwiftUI
import Combine
import Foundation

final class SlidePanelWindowController: NSWindowController {
    private final class SlidePanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    private var hostingView: NSHostingView<SlidepadContentView>?
    private let sidebarModel = SidebarViewModel()

    init() {
        let initialFrame = CGRect(
            x: NSScreen.main?.visibleFrame.maxX ?? 800,
            y: NSScreen.main?.visibleFrame.midY ?? 0,
            width: 540,
            height: 740
        )

        let panel = SlidePanel(
            contentRect: initialFrame,
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        let contentView = SlidepadContentView(sidebarModel: sidebarModel)
        let hosting = NSHostingView(rootView: contentView)
        hosting.frame = panel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hosting)

        super.init(window: panel)
        self.hostingView = hosting
        self.window?.isReleasedWhenClosed = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showPanel() {
        guard let window = self.window, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let width: CGFloat = 540
        let height: CGFloat = 740
        let targetX = visible.maxX - width
        let targetY = visible.midY - height / 2

        let startFrame = CGRect(x: visible.maxX, y: targetY, width: width, height: height)
        let endFrame = CGRect(x: targetX, y: targetY, width: width, height: height)

        window.setFrame(startFrame, display: false)
        window.alphaValue = 1.0
        if !window.isVisible {
            window.orderFrontRegardless()
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().setFrame(endFrame, display: true)
        }
    }

    func hidePanel() {
        guard let window = self.window, let screen = NSScreen.main else {
            window?.orderOut(nil)
            return
        }
        let visible = screen.visibleFrame
        var endFrame = window.frame
        endFrame.origin.x = visible.maxX

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrame(endFrame, display: true)
        }, completionHandler: {
            window.orderOut(nil)
        })
    }

    func showPanelAnchoredToRightEdge() {
        showPanel()
    }

    private func positionWindowAtRightEdge(window: NSWindow) {
        // No-op
    }
}
