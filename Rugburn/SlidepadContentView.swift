import SwiftUI
import FaviconFinder

struct SlidepadContentView: View {
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
                // Toolbar
                HStack(spacing: 8) {
                    TextField("Enter URL", text: $addressBarText, onCommit: navigateFromAddressBar)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                        )
                        .cornerRadius(6)
                        .help("Type or paste a URL, then press Return or Go")

                    Button(action: navigateFromAddressBar) {
                        Image(systemName: "arrow.right.circle.fill")
                            .imageScale(.large)
                    }
                    .buttonStyle(.bordered)
                    .help("Load the URL in the slidepad")

                    Button(action: saveCurrentAddressAsShortcut) {
                        Image(systemName: "star.fill")
                            .imageScale(.large)
                    }
                    .buttonStyle(.bordered)
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
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Web content
                if let url = effectiveURL {
                    MacWebView(url: url, loadError: $loadError, userAgent: currentUserAgent)
                        .id(url)
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
                } else {
                    Text("Select an app from the sidebar or enter a URL")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
