import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
            Text("Rugburn is launching...")
                .font(.title)
                .padding(.top, 8)
        }
        .frame(width: 320, height: 180)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(20)
        .shadow(radius: 12)
    }
}
