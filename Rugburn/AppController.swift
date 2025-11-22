import SwiftUI
import Combine
import AppKit

final class AppController: ObservableObject {
    static let shared = AppController()

    @Published var isPanelVisible: Bool = false

    private var panelController: SlidePanelWindowController?
    private var hotKeyManager: HotKeyManager?

    // Mouse monitoring
    private var globalMouseMoveMonitor: Any?
    private var localMouseMoveMonitor: Any?
    private var globalMouseDownMonitor: Any?

    // Edge behavior tuning
    private let edgeThreshold: CGFloat = 8.0          // distance from right edge to trigger show
    private let edgeHideThreshold: CGFloat = 80.0     // distance from right edge to start considering hide
    private let edgeHideDelay: TimeInterval = 1.2     // delay before auto-hide after moving away

    private var hidePanelTimer: Timer?

    // Simple debouncing / state
    private var panelLastShownAt: Date?

    // Expose current pin state from the panel's sidebar model
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
        hotKeyManager?.registerDefaultHotKey()
    }

    // MARK: - Public control

    func togglePanel() {
        Logger.log("Toggling panel. Current state: \(isPanelVisible)")
        if isPanelVisible {
            hidePanel()
        } else {
            showPanelAtEdge()
        }
    }

    // MARK: - Mouse monitoring setup

    private func installMouseMonitors() {
        // Global monitor: mouse moved when app is NOT active
        globalMouseMoveMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleMouseMoved()
        }

        // Local monitor: mouse moved when app IS active
        localMouseMoveMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved()
            return event
        }

        // Global monitor: mouse down anywhere (we only care when panel is visible)
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.handleGlobalMouseDown()
        }
    }

    // MARK: - Mouse move / edge logic

    private func handleMouseMoved() {
        guard let primaryScreen = NSScreen.main else { return }
        let mouseLocation = NSEvent.mouseLocation

        // Determine which screen the mouse is currently on (multi-monitor)
        let screenUnderMouse = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? primaryScreen
        let screenFrame = screenUnderMouse.frame

        let rightEdgeX = screenFrame.origin.x + screenFrame.size.width
        let atRightEdge = abs(mouseLocation.x - rightEdgeX) <= edgeThreshold
        let farFromEdge = rightEdgeX - mouseLocation.x > edgeHideThreshold

        // Use actual window frame if visible
        let panelFrame = (panelController?.window?.isVisible == true)
            ? (panelController?.window?.frame ?? .zero)
            : .zero

        // Slightly expanded hitbox so tiny movements near the frame don't instantly count as outside.
        let expandedFrame = panelFrame.insetBy(dx: -8, dy: -8)
        let mouseInPanel = expandedFrame.contains(mouseLocation)

        Logger.log("mouseMoved: loc=\(mouseLocation), atRightEdge=\(atRightEdge), farFromEdge=\(farFromEdge), mouseInPanel=\(mouseInPanel), isPanelVisible=\(isPanelVisible), isPinned=\(isPinned)")

        // If the panel is visible and the mouse is over it, we never auto-hide.
        if isPanelVisible && mouseInPanel {
            hidePanelTimer?.invalidate()
            return
        }

        if atRightEdge {
            // At the right edge: cancel pending hides and consider showing
            hidePanelTimer?.invalidate()
            let recentlyHidden = (panelLastShownAt?.timeIntervalSinceNow ?? -10) > -0.3
            if !isPanelVisible && !recentlyHidden {
                Logger.log("Mouse at right edge, showing panel")
                showPanelAtEdge()
            }
        } else if isPanelVisible {
            // Panel is visible, mouse is NOT over the panel.

            if farFromEdge {
                // Don't hide immediately after showing to avoid flicker
                let recentlyShown = (panelLastShownAt?.timeIntervalSinceNow ?? -10) > -0.7
                if recentlyShown { return }

                // Respect pin: don't schedule auto-hide while pinned
                if isPinned { return }

                hidePanelTimer?.invalidate()
                hidePanelTimer = Timer.scheduledTimer(withTimeInterval: edgeHideDelay, repeats: false) { [weak self] _ in
                    guard let self else { return }
                    Logger.log("Auto-hiding panel after mouse moved away")

                    // Double-check pin state and mouse position at fire time
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
                // We moved back closer to the edge or panel: cancel pending hide.
                hidePanelTimer?.invalidate()
            }
        }
    }

    // MARK: - Global click-to-hide

    private func handleGlobalMouseDown() {
        // If the panel isn't visible, nothing to do.
        guard isPanelVisible, let window = panelController?.window else { return }

        let mouseLocation = NSEvent.mouseLocation

        // Compare against the panel window frame in screen coordinates.
        let panelFrame = window.frame
        let expandedFrame = panelFrame.insetBy(dx: -4, dy: -4) // small margin

        let clickInsidePanel = expandedFrame.contains(mouseLocation)

        Logger.log("globalMouseDown: location=\(mouseLocation), clickInsidePanel=\(clickInsidePanel), isPanelVisible=\(isPanelVisible), isPinned=\(isPinned)")

        if !clickInsidePanel {
            // Click was outside our panel window: hide immediately, unless pinned.
            if !isPinned {
                hidePanel()
            }
        }
    }

    // MARK: - Show/hide helpers

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
