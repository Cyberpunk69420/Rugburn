import SwiftUI
import Combine
import AppKit

final class AppController: ObservableObject {
    static let shared = AppController()

    @Published var isPanelVisible: Bool = false
    private var panelController: SlidePanelWindowController?
    private var hotKeyManager: HotKeyManager?
    private var mouseMonitor: Any?
    private let edgeThreshold: CGFloat = 8.0
    private let edgeHideThreshold: CGFloat = 80.0   // a bit farther from edge before hiding
    private let edgeHideDelay: TimeInterval = 0.8   // slightly longer delay before auto-hide
    private var hidePanelTimer: Timer?

    private var lastEdgeState: Bool = false
    private var edgeDebounceTimer: Timer?
    private let edgeDebounceInterval: TimeInterval = 0.2
    private var panelLastShownAt: Date?

    init() {
        self.panelController = SlidePanelWindowController()
        self.hotKeyManager = HotKeyManager()
        self.hotKeyManager?.onToggle = { [weak self] in
            Logger.log("Global hotkey triggered panel toggle")
            DispatchQueue.main.async { self?.togglePanel() }
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event)
        }
        Logger.log("AppController initialized, mouse monitor installed")
    }

    deinit {
        if let monitor = mouseMonitor { NSEvent.removeMonitor(monitor) }
    }

    func start() {
        Logger.log("Registering default hotkey")
        hotKeyManager?.registerDefaultHotKey()
    }

    func togglePanel() {
        Logger.log("Toggling panel. Current state: \(isPanelVisible)")
        if isPanelVisible {
            panelController?.hidePanel()
            isPanelVisible = false
        } else {
            showPanelAtEdge()
        }
    }

    private func handleMouseMoved(_ event: NSEvent) {
        guard let primaryScreen = NSScreen.main else { return }
        let mouseLocation = NSEvent.mouseLocation

        // Determine which screen the mouse is currently on (for multi-monitor / Spaces)
        let screenUnderMouse = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? primaryScreen
        let screenFrame = screenUnderMouse.frame

        let rightEdgeX = screenFrame.origin.x + screenFrame.size.width
        let atRightEdge = abs(mouseLocation.x - rightEdgeX) <= edgeThreshold
        let farFromEdge = rightEdgeX - mouseLocation.x > edgeHideThreshold

        let panelFrame = (panelController?.window?.isVisible == true) ? (panelController?.window?.frame ?? .zero) : .zero
        let expandedFrame = panelFrame.insetBy(dx: -4, dy: -4)
        let mouseInPanel = expandedFrame.contains(mouseLocation)

        Logger.log("mouseMoved: location=\(mouseLocation), atRightEdge=\(atRightEdge), farFromEdge=\(farFromEdge), mouseInPanel=\(mouseInPanel), isPanelVisible=\(isPanelVisible)")

        if atRightEdge {
            hidePanelTimer?.invalidate()
            let recentlyHidden = (panelLastShownAt?.timeIntervalSinceNow ?? -10) > -1.0
            if !isPanelVisible && !recentlyHidden {
                Logger.log("Mouse at right edge, showing panel")
                showPanelAtEdge()
            }
        } else if isPanelVisible && farFromEdge && !mouseInPanel {
            // Don’t hide immediately after showing to avoid flicker
            let recentlyShown = (panelLastShownAt?.timeIntervalSinceNow ?? -10) > -0.7
            if recentlyShown { return }
            hidePanelTimer?.invalidate()
            hidePanelTimer = Timer.scheduledTimer(withTimeInterval: edgeHideDelay, repeats: false) { [weak self] _ in
                guard let self else { return }
                Logger.log("Auto-hiding panel after mouse moved away")
                self.panelController?.hidePanel()
                self.isPanelVisible = false
            }
        }
    }

    private func showPanelAtEdge() {
        panelController?.showPanelAnchoredToRightEdge()
        isPanelVisible = true
        panelLastShownAt = Date()
        Logger.log("Panel shown at edge")
    }

    // TEST: Add a log statement to verify edit capability
    func testEditCapability() {
        Logger.log("Edit capability test: AppController.swift was successfully edited.")
    }
}
