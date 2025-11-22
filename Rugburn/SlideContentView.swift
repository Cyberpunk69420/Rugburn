import SwiftUI
import Foundation
import FaviconFinder

struct SlideContentView: View {
    @ObservedObject var sidebarModel: SidebarViewModel
    @State private var loadError: String? = nil
    @State private var addressBarText: String = ""
    @State private var currentPageURL: URL? = nil
    @State private var showingHotkeyInfo: Bool = false

    private var appController: AppController { AppController.shared }

    private var effectiveURL: URL? {
        currentPageURL ?? sidebarModel.selected?.url
    }

    private var currentUserAgent: String? {
        if sidebarModel.useMobileUserAgent {
            // Mobile: iPhone Safari UA similar to iOS 17 Safari
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) " +
                   "AppleWebKit/605.1.15 (KHTML, like Gecko) " +
                   "Version/17.4 Mobile/15E148 Safari/604.1"
        } else {
            // Desktop: Chrome on macOS UA for maximum compatibility
            return "Mozilla/5.0 (Macintosh; Intel Mac OS X 13_5) " +
                   "AppleWebKit/537.36 (KHTML, like Gecko) " +
                   "Chrome/124.0.0.0 Safari/537.36"
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(viewModel: sidebarModel)

            VStack(spacing: 0) {
                // Toolbar integrated with card
                HStack(spacing: 5) {
                    TextField("Enter URL", text: $addressBarText, onCommit: navigateFromAddressBar)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: NSColor.textBackgroundColor))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.blue.opacity(0.20), lineWidth: 2)
                        )
                        .help("Type or paste a URL, then press Return or Go")

                    Button(action: navigateFromAddressBar) {
                        Image(systemName: "arrow.right.circle.fill")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Load the URL in Rugburn")

                    Button(action: saveCurrentAddressAsShortcut) {
                        Image(systemName: "star.fill")
                            .imageScale(.large)
                    }
                    .buttonStyle(.bordered)
                    .tint(.yellow)
                    .disabled(
                        addressBarText
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )
                    .help("Save the current URL as a bookmark in the sidebar")

                    // Pin toggle
                    Button(action: { sidebarModel.isPinned.toggle() }) {
                        Image(systemName: sidebarModel.isPinned ? "pin.fill" : "pin")
                            .imageScale(.medium)
                            .foregroundColor(sidebarModel.isPinned ? .blue : .primary)
                    }
                    .buttonStyle(.bordered)
                    .help(sidebarModel.isPinned ? "Panel is pinned" : "Pin the panel so it doesn't auto-hide")

                    Button(action: { sidebarModel.useMobileUserAgent.toggle(); reloadForUserAgentChange() }) {
                        Image(systemName: sidebarModel.useMobileUserAgent ? "iphone" : "desktopcomputer")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.bordered)
                    .help(
                        sidebarModel.useMobileUserAgent
                        ? "Using mobile user agent"
                        : "Using desktop user agent"
                    )

                    // Hotkey enable/disable toggle (match pin-toggle visual logic)
                    Button(action: toggleHotkey) {
                        Image(systemName: appController.isHotKeyEnabled ? "keyboard" : "keyboard.slash")
                            .imageScale(.medium)
                            .foregroundColor(appController.isHotKeyEnabled ? .blue : .primary)
                    }
                    .buttonStyle(.bordered)
                    .frame(minWidth: 36)
                    .help(appController.isHotKeyEnabled
                          ? "Disable the ⌘+Shift+. global hotkey"
                          : "Enable the ⌘+Shift+. global hotkey")
                }
                .padding(.horizontal, 5)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .background(Color(NSColor.windowBackgroundColor))
                .sheet(isPresented: $showingHotkeyInfo) {
                    HotkeyInfoView(isPresented: $showingHotkeyInfo)
                }

                // Web content in rounded card
                if let url = effectiveURL {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(color: Color.blue.opacity(0.22), radius: 6, x: 0, y: 8)

                        MacWebView(
                            url: url,
                            loadError: $loadError,
                            userAgent: currentUserAgent,
                            onURLChange: { newURL in
                                guard let finalURL = newURL else { return }
                                currentPageURL = finalURL
                                addressBarText = finalURL.absoluteString
                            }
                        )
                        .id(url)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onAppear {
                            addressBarText = url.absoluteString
                            currentPageURL = url
                        }
                        .onChange(of: sidebarModel.selected?.id) { _, _ in
                            if let selectedURL = sidebarModel.selected?.url {
                                currentPageURL = selectedURL
                                addressBarText = selectedURL.absoluteString
                            }
                        }
                    }
                    .padding(.horizontal, 5) // was 18, match toolbar to align edges
                    .padding(.bottom, 14)
                } else {
                    Text("Select an app from the sidebar or enter a URL")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(NSColor.windowBackgroundColor))
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    // MARK: - URL / search classification helpers
    private enum AddressInput {
        case url(URL)
        case search(String)
    }

    private func classifyAddressInput(_ raw: String) -> AddressInput? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.scheme != nil { return .url(url) }
        if trimmed.contains(" ") { return .search(trimmed) }

        let looksLikeHost = trimmed.contains(".") || trimmed.contains(":") || trimmed == "localhost"
        if looksLikeHost {
            let candidate = "https://" + trimmed
            if let url = URL(string: candidate) { return .url(url) }
        }
        return .search(trimmed)
    }

    private func googleSearchURL(for query: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
    }

    // MARK: - Actions
    private func navigateFromAddressBar() {
        let raw = addressBarText
        guard let classified = classifyAddressInput(raw) else { return }

        let destination: URL?
        switch classified {
        case .url(let url):
            destination = url
        case .search(let query):
            destination = googleSearchURL(for: query)
        }

        guard let url = destination else {
            Logger.log("Invalid address bar input: \(raw)", level: .warning)
            return
        }

        currentPageURL = url
    }

    private func saveCurrentAddressAsShortcut() {
        let raw = addressBarText
        guard let classified = classifyAddressInput(raw) else { return }

        let finalURL: URL
        switch classified {
        case .url(let url):
            finalURL = url
        case .search(let query):
            guard let searchURL = googleSearchURL(for: query) else { return }
            finalURL = searchURL
        }

        let hostName = finalURL.host ?? finalURL.absoluteString
        let displayName = hostName
            .replacingOccurrences(of: "www.", with: "")
            .capitalized

        let item = WebAppItem(name: displayName, url: finalURL, iconSymbol: nil, userAgent: nil)
        sidebarModel.items.append(item)
        Persistence.saveItems(sidebarModel.items)
        sidebarModel.fetchFaviconIfNeeded(for: item)
        // Do NOT change sidebarModel.selected here; that would reload the page on bookmark.
    }

    // MARK: - Helpers for UA toggle

    /// When switching between mobile and desktop, reload the current page.
    /// If switching to desktop from an m. domain, request the non-m. host instead.
    private func reloadForUserAgentChange() {
        guard var url = currentPageURL ?? sidebarModel.selected?.url else { return }

        if !sidebarModel.useMobileUserAgent {
            // We just switched to desktop; if this is an m.* host, strip the "m." prefix.
            if let host = url.host, host.hasPrefix("m."),
               var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                let newHost = String(host.dropFirst(2))
                components.host = newHost
                if let rewritten = components.url {
                    url = rewritten
                }
            }
        }

        // Trigger a reload by updating currentPageURL (effectiveURL will change to this).
        currentPageURL = url
    }

    private func toggleHotkey() {
        let newValue = !appController.isHotKeyEnabled
        appController.setHotKeyEnabled(newValue)
        if newValue {
            // Show info when enabling
            showingHotkeyInfo = true
        }
    }
}

struct HotkeyInfoView: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Rugburn Global Hotkey")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("The current global shortcut is:")
                        .font(.headline)

                    Text("⌘+Shift+.")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)

                    Text("Use this shortcut to quickly show or hide the Rugburn panel from anywhere.")

                        .foregroundColor(.secondary)
                }


                Section {
                    Text("Changing the Hotkey")
                        .fontWeight(.semibold)

                    Text("Rugburn currently uses a fixed system-level shortcut based on the macOS hotkey API (Carbon): ⌘+Shift+.")
                        .foregroundColor(.secondary)

                    Text("Future versions will let you change this from inside Rugburn. For now, you can adjust other shortcuts globally in System Settings > Keyboard. Press Close or Escape to dismiss this window.")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical)
            }
            .frame(width: 450, height: 400)
            .navigationTitle("Hotkey Info")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
