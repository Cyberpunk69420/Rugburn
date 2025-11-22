import SwiftUI
import Foundation
import FaviconFinder

struct SlideContentView: View {
    @ObservedObject var sidebarModel: SidebarViewModel
    @State private var loadError: String? = nil
    @State private var addressBarText: String = ""
    @State private var currentPageURL: URL? = nil

    private var effectiveURL: URL? {
        currentPageURL ?? sidebarModel.selected?.url
    }

    private var currentUserAgent: String? {
        if sidebarModel.useMobileUserAgent {
            // iPhone Safari UA
            return "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        } else {
            return nil // system desktop UA
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(viewModel: sidebarModel)

            VStack(spacing: 0) {
                // Toolbar integrated with card
                HStack(spacing: 8) {
                    TextField("Enter URL", text: $addressBarText, onCommit: navigateFromAddressBar)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(nsColor: NSColor.textBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.15), lineWidth: 1)
                        )
                        .help("Type or paste a URL, then press Return or Go")

                    Button(action: navigateFromAddressBar) {
                        Image(systemName: "arrow.right.circle.fill")
                            .imageScale(.large)
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Load the URL in the Rugburn")

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

                    Button(action: { sidebarModel.useMobileUserAgent.toggle() }) {
                        Image(systemName: sidebarModel.useMobileUserAgent ? "iphone" : "desktopcomputer")
                            .imageScale(.medium)
                    }
                    .buttonStyle(.bordered)
                    .help(
                        sidebarModel.useMobileUserAgent
                        ? "Using mobile user agent"
                        : "Using desktop user agent"
                    )
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(Color(NSColor.windowBackgroundColor))

                // Web content in rounded card
                if let url = effectiveURL {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 8)

                        MacWebView(url: url, loadError: $loadError, userAgent: currentUserAgent)
                            .id(url)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .onAppear {
                                addressBarText = url.absoluteString
                                currentPageURL = url
                            }
                            .onChange(of: sidebarModel.selected?.id) { oldValue, newValue in
                                if let selectedURL = sidebarModel.selected?.url {
                                    currentPageURL = selectedURL
                                    addressBarText = selectedURL.absoluteString
                                }
                            }
                    }
                    .padding(.horizontal, 18)
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

        // If user typed a full URL (with scheme), try it directly
        if let url = URL(string: trimmed), url.scheme != nil {
            return .url(url)
        }

        // If it contains spaces, treat as a search query
        if trimmed.contains(" ") { return .search(trimmed) }

        // Heuristic: if it has a dot or a colon (port), treat as a host, otherwise search
        let looksLikeHost = trimmed.contains(".") || trimmed.contains(":") || trimmed == "localhost"
        if looksLikeHost {
            let candidate = "https://" + trimmed
            if let url = URL(string: candidate) {
                return .url(url)
            }
        }

        // Fallback: search term (single word, no obvious host)
        return .search(trimmed)
    }

    private func googleSearchURL(for query: String) -> URL? {
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: query)
        ]
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
        // Trigger favicon fetch for this newly created bookmark as well
        sidebarModel.fetchFaviconIfNeeded(for: item)
        // Do NOT change sidebarModel.selected here; that would reload/navigate the page on bookmark.
    }
}
