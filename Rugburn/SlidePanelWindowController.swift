import AppKit
import SwiftUI
import Combine
import Foundation

final class SlidePanelWindowController: NSWindowController, NSWindowDelegate {
    private final class SlidePanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    private var hostingView: NSHostingView<AnyView>?
    private let sidebarModel = SidebarViewModel()

    // Expose pin state so external controllers can respect it
    var sidebarPinned: Bool { sidebarModel.isPinned }

    // Global click-outside monitor and optional auto-hide timer
    private var globalClickMonitor: Any?
    private var autoHideTimer: Timer?

    init() {
        let initialFrame = CGRect(
            x: NSScreen.main?.visibleFrame.maxX ?? 800,
            y: NSScreen.main?.visibleFrame.midY ?? 0,
            width: 540,
            height: 800
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

        // Build the root SwiftUI view without capturing self
        let slideView = SlideContentView(sidebarModel: sidebarModel)
        let roundedContainer = AnyView(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(nsColor: NSColor.windowBackgroundColor))
                slideView
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        )

        let hosting = NSHostingView(rootView: roundedContainer)
        hosting.frame = panel.contentView?.bounds ?? .zero
        hosting.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hosting)

        super.init(window: panel)
        self.hostingView = hosting
        self.window?.isReleasedWhenClosed = false
        self.window?.delegate = self

        // Set up global click-outside monitoring
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let window = self.window else { return }
            let mouseLocation = NSEvent.mouseLocation
            // If click is outside the panel frame, try to auto-hide
            if !window.frame.contains(mouseLocation) {
                self.attemptAutoHidePanel()
            }
        }
    }

    deinit {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        autoHideTimer?.invalidate()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Attempt to auto-hide the panel, respecting pin state
    func attemptAutoHidePanel() {
        if sidebarModel.isPinned {
            // When pinned, auto-hide is suspended
            return
        }
        hidePanel()
    }

    // Optional: external callers can refresh the inactivity timer
    func restartAutoHideTimer(interval: TimeInterval = 5.0) {
        autoHideTimer?.invalidate()
        guard !sidebarModel.isPinned else { return }
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.attemptAutoHidePanel()
        }
    }

    func cancelAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }

    func showPanel() {
        guard let window = self.window, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let width: CGFloat = 540
        let height: CGFloat = 800
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

        // Restart inactivity timer when panel is shown
        restartAutoHideTimer()
    }

    func hidePanel() {
        cancelAutoHideTimer()

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
