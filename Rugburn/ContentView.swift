import SwiftUI

struct ContentView: View {
    @StateObject private var sidebarModel = SidebarViewModel()

    var body: some View {
        SlidepadContentView(sidebarModel: sidebarModel)
            .frame(minWidth: 600, minHeight: 400)
            .background(Color(NSColor.windowBackgroundColor))
    }
}
