import SwiftUI

@main
struct RugburnApp: App {
    init() {
        showSplashPanel()
        AppController.shared.start()
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }

    private func showSplashPanel() {
        let splash = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        splash.level = .floating
        splash.center()
        splash.isReleasedWhenClosed = true
        splash.contentView = NSHostingView(rootView: SplashView())
        splash.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            splash.close()
        }
    }
}
