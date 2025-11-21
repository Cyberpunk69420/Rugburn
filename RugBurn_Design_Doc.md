# OpenSlide: Project Design Document

## 1. Executive Summary

**Project Name:** OpenSlide **Platform:** macOS (14.0+) **Language:** Swift 5.9+ **Frameworks:** SwiftUI, AppKit, WebKit, Combine **Goal:** Create an open-source, personal-use clone of "a slide out browser." The app acts as a secondary browser that "slides in" from the edge of the screen, allowing quick access to web-apps (Slack, Notion, ChatGPT, etc.) without cluttering the main workspace or Dock.

## 2. Core Features Scope

### 2.1 Minimum Viable Product (MVP)

These are the features strictly required to make the app usable for v1.0.

* **The "Slide" Window:** A window attached to the right (or left) edge of the screen that hides when lost focus and appears on hover/click.

* **Global Hotkey:** A keyboard shortcut (e.g., `Command + Shift + .`) to toggle the window's visibility from anywhere.

* **Webview Container:** A functional web browser based on `WKWebView`.

* **Sidebar Navigation:** A vertical strip of icons to switch between different web apps.

* **Persistence:** The app remembers which URLs you added and your login sessions (cookies) between launches.

### 2.2 Future Features (v2.0)

* **Mobile User Agent Spoofing:** Forcing websites to load their mobile versions for the narrow window.

* **Notification Bridging:** Showing badges on the sidebar icons when the web app receives a notification.

* **Auto-Hide:** Hiding the window automatically when the mouse moves away.

## 3. Technical Architecture

### 3.1 High-Level Diagram

The app follows a modified MVVM (Model-View-ViewModel) pattern.

* **WindowController (AppKit):** Manages the physical window, screen edge detection, and sliding animations.

* **RootView (SwiftUI):** The main interface hosting the Sidebar and the Active Web View.

* **WebViewModel (ObservableObject):** Manages the state of the browser (URL, loading state, title).

* **PersistenceLayer:** Saves the user's list of apps to disk (JSON or SwiftData).

### 3.2 Key Technical Components

#### A. The Floating Window (`NSPanel`)

Standard SwiftUI `WindowGroup` is not powerful enough for this. We will use an `NSPanel` subclass.

* **Style Mask:** `.nonactivatingPanel` (allows interaction without stealing focus from the current active app entirely) + `.borderless`.

* **Level:** `.floating` (keeps it above standard windows).

* **Collection Behavior:** `.canJoinAllSpaces`, `.fullScreenAuxiliary` (allows it to appear over full-screen apps).

#### B. The Browser Engine (`WKWebView`)

We cannot use the standard SwiftUI `Link` or `SafariView`. We need a raw `WKWebView` wrapped in `NSViewRepresentable`.

* **Why?** We need control over cookies, user agents, and javascript injection to make the sites feel like "apps."

#### C. Global Hotkeys

We will use the `HotKey` library (easy to implement) or `Carbon.framework` event registration to listen for global key presses even when the app is in the background.

## 4. User Interface Design (SwiftUI)

The UI is divided into two horizontal sections:

```
+---+-----------------------------------+
| S |                                   |
| I |                                   |
| D |                                   |
| E |        Web Content Area           |
| B |         (WKWebView)               |
| A |                                   |
| R |                                   |
|   |                                   |
+---+-----------------------------------+
```

1. **Sidebar (Width: ~60px):**

   * Vertical `VStack`.

   * `ScrollView` containing circular icons for each app.

   * "Add (+)" button at the bottom to add a new URL.

   * Settings gear icon.

2. **Content Area (Width: Flexible):**

   * Displays the `WebView` of the selected sidebar item.

   * Top bar (optional): Back/Forward buttons, Refresh.

## 5. Data Model

We need a simple structure to hold the "Apps" the user adds.

```
struct WebAppItem: Identifiable, Codable {
    var id: UUID
    var name: String
    var url: URL
    var iconSymbol: String // SF Symbol name or local image path
    var userAgent: String? // Optional custom UA
}
```

## 6. Step-by-Step Development Roadmap

Use this roadmap when prompting Gemini/ChatGPT to generate code. Tackle one section at a time.

### Phase 1: The Floating Window (The Hardest Part)

**Goal:** Get a blank window to float on the right side of the screen and toggle with a button.

* **Task:** Create `SlideOverWindowController.swift`.

* **Task:** Configure `NSPanel` properties (transparent, borderless, floating).

* **Task:** Implement logic to set the window frame size to `NSScreen.main.visibleFrame.height`.

### Phase 2: The WebView Wrapper

**Goal:** Render https://www.google.com/search?q=Google.com inside that window.

* **Task:** Create `WebView.swift` using `NSViewRepresentable`.

* **Task:** Pass a `URL` binding to it so changing the variable changes the website.

### Phase 3: The Sidebar & State

**Goal:** Switch between Google and YouTube.

* **Task:** Create the `WebAppItem` model.

* **Task:** Build the SwiftUI Sidebar view.

* **Task:** Connect the Sidebar selection to the WebView URL.

### Phase 4: Polish & Interaction

**Goal:** Make it feel like a native utility.

* **Task:** Add "Slide In" and "Slide Out" animations using `NSAnimationContext`.

* **Task:** Implement the Global Hotkey.

* **Task:** Add "Click outside to close" logic (monitoring `NSEvent.addGlobalMonitorForEvents`).

## 7. Code Snippets for "Tricky" Parts

Here are specific snippets to use when you get stuck on the window management.

**The Panel Configuration:**

```
class SlideWindow: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless, .resizable], 
            backing: .buffered, 
            defer: false
        )
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
    }
}
```

**The WebView Wrapper:**

```
struct WebView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        return WKWebView()
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        webView.load(request)
    }
}
```
