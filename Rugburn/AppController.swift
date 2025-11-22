import SwiftUI
import Combine
import AppKit

final class AppController: ObservableObject {
    static let shared = AppController()

    @Published var isPanelVisible: Bool = false
    @Published var isHotKeyEnabled: Bool = true

    private var panelController: SlidePanelWindowController?
    private var hotKeyManager: HotKeyManager?

    // Mouse monitoring
    private var globalMouseMoveMonitor: Any?
    private var localMouseMoveMonitor: Any?
    private var globalMouseDownMonitor: Any?

    // Edge behavior tuning
    private let edgeThreshold: CGFloat = 8.0
    private let edgeHideThreshold: CGFloat = 80.0
    private let edgeHideDelay: TimeInterval = 1.2

    private var hidePanelTimer: Timer?
    private var panelLastShownAt: Date?

    private var isPinned: Bool {
        panelController?.sidebarPinned ?? false
    }

    init() {
        panelController = SlidePanelWindowController()
        hotKeyManager = HotKeyManager()

        hotKeyManager?.onToggle = { [weak self] in
            Logger.log("Global hotkey triggered panel toggle")
            DispatchQueue.main.async { self?.togglePanel() }
        }

        installMouseMonitors()
        Logger.log("AppController initialized, mouse monitors installed")
    }

    deinit {
        if let monitor = globalMouseMoveMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMouseMoveMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = globalMouseDownMonitor { NSEvent.removeMonitor(monitor) }
    }

    func start() {
        Logger.log("Registering default hotkey")
        if isHotKeyEnabled {
            hotKeyManager?.registerDefaultHotKey()
        }
    }

    func setHotKeyEnabled(_ enabled: Bool) {
        isHotKeyEnabled = enabled
        if enabled {
            hotKeyManager?.registerDefaultHotKey()
        } else {
            hotKeyManager?.unregisterHotKey()
        }
    }

    func togglePanel() {
        Logger.log("Toggling panel. Current state: \(isPanelVisible)")
        if isPanelVisible {
            hidePanel()
        } else {
            showPanelAtEdge()
        }
    }

    private func installMouseMonitors() {
        globalMouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved()
        }

        localMouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved()
            return event
        }

        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.handleGlobalMouseDown()
        }
    }

    private func handleMouseMoved() {
        guard let primaryScreen = NSScreen.main else { return }
        let mouseLocation = NSEvent.mouseLocation

        let screenUnderMouse = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? primaryScreen
        let screenFrame = screenUnderMouse.frame

        let rightEdgeX = screenFrame.origin.x + screenFrame.size.width
        let atRightEdge = abs(mouseLocation.x - rightEdgeX) <= edgeThreshold
        let farFromEdge = rightEdgeX - mouseLocation.x > edgeHideThreshold

        let panelFrame = (panelController?.window?.isVisible == true)
            ? (panelController?.window?.frame ?? .zero)
            : .zero

        let expandedFrame = panelFrame.insetBy(dx: -8, dy: -8)
        let mouseInPanel = expandedFrame.contains(mouseLocation)

        Logger.log("mouseMoved: loc=\(mouseLocation), atRightEdge=\(atRightEdge), farFromEdge=\(farFromEdge), mouseInPanel=\(mouseInPanel), isPanelVisible=\(isPanelVisible), isPinned=\(isPinned)")

        if isPanelVisible && mouseInPanel {
            hidePanelTimer?.invalidate()
            return
        }

        if atRightEdge {
            hidePanelTimer?.invalidate()
            let recentlyHidden = (panelLastShownAt?.timeIntervalSinceNow ?? -10) > -0.3
            if !isPanelVisible && !recentlyHidden {
                Logger.log("Mouse at right edge, showing panel")
                showPanelAtEdge()
            }
        } else if isPanelVisible {
            if farFromEdge {
                let recentlyShown = (panelLastShownAt?.timeIntervalSinceNow ?? -10) > -0.7
                if recentlyShown { return }
                if isPinned { return }

                hidePanelTimer?.invalidate()
                hidePanelTimer = Timer.scheduledTimer(withTimeInterval: edgeHideDelay, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    Logger.log("Auto-hiding panel after mouse moved away")

                    let currentLocation = NSEvent.mouseLocation
                    let currentPanelFrame = (self.panelController?.window?.isVisible == true)
                        ? (self.panelController?.window?.frame ?? .zero)
                        : .zero
                    let currentExpanded = currentPanelFrame.insetBy(dx: -8, dy: -8)
                    let stillInPanel = currentExpanded.contains(currentLocation)

                    if !self.isPinned && !stillInPanel {
                        self.hidePanel()
                    }
                }
            } else {
                hidePanelTimer?.invalidate()
            }
        }
    }

    private func handleGlobalMouseDown() {
        guard isPanelVisible, let window = panelController?.window else { return }

        let mouseLocation = NSEvent.mouseLocation
        let panelFrame = window.frame
        let expandedFrame = panelFrame.insetBy(dx: -4, dy: -4)

        let clickInsidePanel = expandedFrame.contains(mouseLocation)

        Logger.log("globalMouseDown: location=\(mouseLocation), clickInsidePanel=\(clickInsidePanel), isPanelVisible=\(isPanelVisible), isPinned=\(isPinned)")

        if !clickInsidePanel && !isPinned {
            hidePanel()
        }
    }

    private func showPanelAtEdge() {
        panelController?.showPanelAnchoredToRightEdge()
        isPanelVisible = true
        panelLastShownAt = Date()
        Logger.log("Panel shown at edge")
    }

    private func hidePanel() {
        hidePanelTimer?.invalidate()
        panelController?.hidePanel()
        isPanelVisible = false
        panelLastShownAt = Date()
        Logger.log("Panel hidden")
    }
}
