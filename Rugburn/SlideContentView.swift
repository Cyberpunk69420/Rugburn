import SwiftUI
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

    // MARK: - Actions

    private func navigateFromAddressBar() {
        let raw = addressBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        let normalized: String
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            normalized = raw
        } else {
            normalized = "https://" + raw
        }

        guard let url = URL(string: normalized) else {
            Logger.log("Invalid URL typed in address bar: \(raw)", level: .warning)
            return
        }

        currentPageURL = url
    }

    private func saveCurrentAddressAsShortcut() {
        let raw = addressBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        let urlString: String
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            urlString = raw
        } else {
            urlString = "https://" + raw
        }

        guard let url = URL(string: urlString) else { return }

        let hostName = url.host ?? urlString
        let displayName = hostName
            .replacingOccurrences(of: "www.", with: "")
            .capitalized

        let item = WebAppItem(name: displayName, url: url, iconSymbol: nil, userAgent: nil)
        sidebarModel.items.append(item)
        Persistence.saveItems(sidebarModel.items)
        // Trigger favicon fetch for this newly created bookmark as well
        sidebarModel.fetchFaviconIfNeeded(for: item)
        sidebarModel.selected = item
    }
}
