# Rugburn (sliding-like Side Panel Browser)

_Last updated: 2025-11-20_

This document summarizes the current architecture, implemented features, known behaviors, and next steps for the **Rugburn** macOS app (a personal sliding side panel browser).

---

## High-level concept

Rugburn is a macOS app that provides a slide-out web browser attached to the **right edge** of the screen. The user can:

- Trigger the panel by moving the mouse to the right edge.
- Keep a list of **bookmarked web apps/sites** in a sidebar.
- Quickly navigate via an **address bar** at the top of the panel.
- Have the panel float above other apps without fully taking focus.



---

## Architecture overview

### Entry point

- `RugburnApp.swift`
  - SwiftUI `@main` entry point.
  - Creates/owns a shared `AppController` (singleton) and calls `start()` to register hotkeys and mouse monitors.
  - Shows a splash screen on launch before the slide panel is first used.

### AppController

- File: `AppController.swift`
- Type: `final class AppController: ObservableObject`
- Responsibilities:
  - Owns a single `SlidePanelWindowController` instance.
  - Manages global state: `@Published var isPanelVisible: Bool`.
  - Registers a global hotkey via `HotKeyManager` and handles toggle callbacks.
  - Installs **global and local mouse move monitors** (`NSEvent.addGlobalMonitorForEvents` + `addLocalMonitorForEvents`) to implement **edge detection**.
  - Edge logic:
    - Uses `NSScreen.screens` and `NSEvent.mouseLocation` to determine which screen the mouse is on.
    - Considers the mouse to be at the right edge if within `edgeThreshold` (currently 3 px) of the right side of the current screen.
    - Shows the panel when the mouse hits the right edge and `isPanelVisible == false`.
    - Auto-hides the panel when:
      - The panel is visible.
      - The mouse is farther than `edgeHideThreshold` (currently 80 px) from the right edge.
      - The mouse is not inside the panel’s expanded frame (slight inset so near misses don’t count as outside).
      - A short time (`edgeHideDelay`, currently 0.8 s) has elapsed and the panel was not **very recently shown** (avoid flicker).
  - Calls `panelController.showPanelAnchoredToRightEdge()` when showing and `panelController.hidePanel()` when hiding.
  - Persists the last shown time (`panelLastShownAt`) to moderate hide aggressiveness.

### Slide panel window

- File: `SlidePanelWindowController.swift`
- Type: `final class SlidePanelWindowController: NSWindowController`
- Responsibilities:
  - Creates and manages the actual **panel window** used for the slide-out UI.
  - Uses a custom `SlidePanel: NSPanel` subclass that:
    - Overrides `canBecomeKey` and `canBecomeMain` to `true`, so the window can accept keyboard focus even though it’s nominally non-activating.
  - Window characteristics:
    - Style mask: `[.nonactivatingPanel, .borderless, .resizable]`.
    - Level: `.floating`.
    - `collectionBehavior`: `[.canJoinAllSpaces, .fullScreenAuxiliary]` so it follows Spaces and works with full-screen apps.
    - `isOpaque = false`, `backgroundColor = .clear`, `hasShadow = true`.
  - Embeds SwiftUI:
    - Creates a `slidingContentView` with a shared `SidebarViewModel`.
    - Wraps it in `NSHostingView` and installs it as a subview of the panel’s content view with autoresizing mask `[.width, .height]`.

#### Slide animation

- `showPanel()`
  - Determines the **visibleFrame** of `NSScreen.main`.
  - Computes a fixed width (540) and height (740) and centers vertically.
  - Creates:
    - `startFrame`: panel fully off-screen at the **right** (`x = visible.maxX`).
    - `endFrame`: panel anchored in from the right (`x = visible.maxX - width`).
  - Sets the window frame to `startFrame`, ensures `alphaValue = 1.0`, and calls `orderFrontRegardless()` if not visible.
  - Runs an explicit `NSAnimationContext` animation (duration 0.18s, ease-out) that animates the window’s frame from `startFrame` to `endFrame` using `window.animator().setFrame(endFrame, display: true)`.

- `hidePanel()`
  - Computes a new frame where `origin.x = visible.maxX` (moves the panel fully off-screen to the right but keeps y/size).
  - Runs a second `NSAnimationContext` animation (duration 0.16s, ease-in) animating the panel to that off-screen position.
  - On completion, calls `window.orderOut(nil)` to fully hide the panel.

The result is an explicit, clearly visible slide-in from and slide-out to the right edge, independent of app focus.

---

## SwiftUI content structure

### slidingContentView

- File: `slidingContentView.swift`
- Type: `struct slidingContentView: View`
- State and bindings:
  - `@ObservedObject var sidebarModel: SidebarViewModel` – shared bookmark list and selection state.
  - `@State private var loadError: String?` – for web load errors (currently not surfaced in UI yet).
  - `@State private var addressBarText: String` – contents of the URL field.
  - `@State private var currentPageURL: URL?` – currently loaded URL.
  - `effectiveURL` computed as `currentPageURL ?? sidebarModel.selected?.url`.

- Layout:
  - `HStack(spacing: 0)`
    - Left: `SidebarView(viewModel: sidebarModel)` – vertical list of web app shortcuts with plus button.
    - Right: `VStack(spacing: 0)`
      - Top: URL bar row (`HStack`):
        - `TextField("Enter URL", text: $addressBarText, onCommit: navigateFromAddressBar)`
          - Styled with:
            - `.background(Color.white)`
            - `.foregroundColor(.black)`
            - Rounded border using `RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.6), lineWidth: 1)`
          - This makes the URL bar clearly look like an interactive text field.
        - `Go` button – calls `navigateFromAddressBar()`.
        - `★ Save` button – calls `saveCurrentAddressAsShortcut()` and is disabled when the field is empty.
      - Main content:
        - If `effectiveURL` exists: shows `MacWebView(url: url, loadError: $loadError)`
          - `.id(url)` so navigation forces a reload when URL changes.
          - `onAppear` and `onChange(of: sidebarModel.selected?.id)` keep `addressBarText` and `currentPageURL` in sync with the selected bookmark.
        - Else: placeholder text `"Select an app from the sidebar or enter a URL"` centered.

#### URL navigation

- `navigateFromAddressBar()`
  - Trims whitespace from `addressBarText`.
  - Normalizes via `sidebarModel.normalizedUrlString(_)` (adds scheme if missing, etc.).
  - Creates a `URL` from the normalized string; if invalid, logs a warning.
  - Sets `currentPageURL` to the new URL; `MacWebView` then reloads.

#### Saving shortcuts

- `saveCurrentAddressAsShortcut()`
  - Normalizes `addressBarText` to a URL.
  - If the currently selected bookmark has the **same URL**:
    - Updates that bookmark (to keep any other metadata in sync) and reassigns `selected`.
  - Else:
    - Creates a new `WebAppItem` with name=`addName` if set, else the raw string.
    - Appends to `sidebarModel.items` and selects it.
  - Persists bookmarks using `Persistence.saveItems`.

### SidebarView and SidebarViewModel

- File: `SidebarView.swift`
- `SidebarViewModel: ObservableObject`
  - Holds `[WebAppItem]`, `selected: WebAppItem?`, add-bookmark state (`addName`, `addUrl`, `showAddSheet`), etc.
  - Provides:
    - `normalizedUrlString(_:)` – used by the URL bar and save logic.
    - `addItem()` and `delete(_:)` for bookmark management.
  - Loads and saves bookmarks through `Persistence.swift` to keep them across launches.

- `SidebarView: View`
  - Vertical bar with:
    - Circle buttons for each `WebAppItem` (icon = first letter + color, currently the simplified “letter in a circle” design).
    - Tap to select (navigates the main web view).
    - Plus button at bottom to open an add shortcut sheet.
  - Delete UI: currently still shows a trash control; there is a plan to move to right-click / edit mode to save horizontal space.

### WebView wrapper

- File: `WebView.swift`
- Wraps `WKWebView` for use in SwiftUI via `NSViewRepresentable`.
- Loads a specified `URL` and handles cookies/session normally.
- Recent work fixed WebKit crashes and sandbox/network entitlement issues so that web pages now load reliably.

---

## Persistence and models

- File: `Models.swift`
  - Defines `struct WebAppItem: Codable, Identifiable, Equatable` (id, name, URL, iconSymbol, optional userAgent, etc.).

- File: `Persistence.swift`
  - Persists `[WebAppItem]` to disk (likely into Application Support) using a JSON file.
  - `SidebarViewModel` uses this helper to load bookmarks at startup and save them after changes.

Bookmarks you add through the UI should persist across launches.

---

## Focus and interaction behavior

Current state (after many iterations):

- The panel is a **non-activating floating NSPanel**; it appears above other apps while they remain active.
- Because `SlidePanel` overrides `canBecomeKey` and `canBecomeMain`, clicking in:
  - the URL bar, or
  - a web page text input

  gives the panel keyboard focus and allows typing. The previous bug where typing beeped and went to another window is resolved.
- Hovering over links shows the correct hand cursor and links navigate as expected.

We have tuned edge detection such that:

- On first launch, after the app finishes starting, moving the mouse to the right edge shows the panel without needing to click the dock icon.
- The panel no longer disappears aggressively when moving within or near the panel; it waits for genuine movement away from both the edge and panel plus a short delay.

---

## Visual design status

- Sidebar:
  - Dark background, vertical list of circular shortcut icons (first letter of name, colored background) and a plus button at the bottom.
  - There is still a small gap between the sidebar and the main web view only if the layout is adjusted; currently this gap has been removed.
- URL bar:
  - Now clearly styled: white background, black text, gray rounded border.
  - Sits flush against the web view below (no 1px gap).
- Window size:
  - Fixed width ~540 pts and height ~740 pts, anchored from the right edge and vertically centered.
  - Design intent is a shorter, wider panel rather than full-screen-height.

Further visual polish (rounded outer corners, chrome, more refined sidebar spacing) is still planned.

---

## Features implemented so far

- [x] Launchable macOS app with working entitlements and app icon in asset catalog.
- [x] Slide-out panel attached to right edge with explicit slide in/out animation.
- [x] Global edge detection with relaxed, stable auto-hide behavior.
- [x] Sidebar of web app shortcuts (bookmarks).
- [x] Add new shortcut from UI.
- [x] Persistent storage of shortcuts across launches.
- [x] Working `WKWebView` loading of both built-in and user-added URLs.
- [x] Address bar that:
  - Shows the current URL when a shortcut is selected or navigation completes.
  - Accepts user input and navigates on Return or `Go`.
  - Has clear visual affordance (white, bordered).
- [x] Ability to save the current URL as a new bookmark (or update existing when URLs match).
- [x] Basic logging via `Logger.log` across core flows for debugging.

---

## Known issues / quirks (as of this summary)

These may have improved partially, but they are worth re-checking in future iterations:

1. **Bookmark management UX**
   - Deleting is currently via visible trash icons next to each shortcut, which consumes horizontal space. The plan is to move to either:
     - a right-click context menu, or
     - an "edit" mode that temporarily reveals delete icons.

2. **URL vs bookmark independence**
   - The design goal is:
     - Clicking a bookmark sets the URL bar and navigates, but typing arbitrary URLs should not overwrite an existing bookmark unless explicitly saved.
   - Logic for deciding whether to update the current bookmark vs create a new one has been improved but should be validated with more scenarios.

3. **Spaces / full-screen interaction edge cases**
   - With `.canJoinAllSpaces` and `.fullScreenAuxiliary` the panel tracks Spaces and full-screen apps, but some combinations of three-finger swipes and app focus may still have subtle behaviors.

4. **Error display**
   - `loadError` is plumbed into `slidingContentView` and `MacWebView` but not yet surfaced in the UI (e.g., banner or overlay when a page fails to load).

5. **Performance / animation smoothing**
   - Slide durations are short (0.18s in, 0.16s out). They generally feel snappy but can be tweaked.

---

## Potential next steps

Short-term polish and behavior:

1. **Finalize bookmark UX**
   - Replace visible trash icons with a more compact deletion flow (context menu or edit mode).
   - Confirm that saving a new URL while a bookmark is selected creates a new bookmark when URLs differ.

2. **Improve URL bar behavior**
   - Auto-focus the URL bar when the panel first opens (optional).
   - Add a small lock icon or favicon placeholder to the left of the field.

3. **Advanced panel behavior**
   - Option to pin the panel open (disable auto-hide) via a small pin button.
   - Option for slide-in from left edge or configurable screen edge.

4. **Persist window geometry**
   - Remember last-used width/height and vertical offset instead of using fixed 540×740 each launch.

5. **Visual design**
   - Rounded outer corners on the whole panel window.
   - Subtle drop shadow and blur effects for a more modern look.

Longer-term ideas:

- Multi-profile / workspace support (different bookmark sets per context).
- Per-bookmark user agent overrides.
- Integration with macOS keychain or credential storage (was discussed but not prioritized yet).

---

## How to continue development

When resuming work, this file should give you enough context to:

- Quickly find the right file and class for any given behavior (edge detection, animation, URL routing, bookmarks, etc.).
- Understand how bookmarks, the URL bar, and the web view are wired together.
- Know what behaviors are already tuned (slide timing, focus, persistence) so changes dont accidentally regress them.

For significant new feature work, update this `PROJECT_SUMMARY.md` with:

- New public structs/classes and their roles.
- Any changes to edge behavior, window sizing, or persistence formats.
- A short list of new known issues and next steps.
