import SwiftUI
import Combine
import AppKit

struct SidebarView: View {
    @ObservedObject var viewModel: SidebarViewModel

    let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .yellow, .teal, .indigo]

    func colorForItem(_ item: WebAppItem) -> Color {
        let idx = abs(item.name.hashValue) % colors.count
        return colors[idx]
    }

    private func faviconImage(for item: WebAppItem) -> NSImage? {
        guard let name = item.faviconFileName,
              let url = FaviconCache.shared.fileURL(forFileName: name),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        return image
    }

    private var sidebarBackground: Color {
        Color(nsColor: NSColor.controlBackgroundColor)
    }

    var body: some View {
        VStack(spacing: 8) {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.items) { item in
                        let isSelected = viewModel.selected?.id == item.id

                        Button(action: {
                            viewModel.selected = item
                        }) {
                            Group {
                                if let nsImage = faviconImage(for: item) {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30, height: 30)
                                        .padding(6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(isSelected ? Color.teal.opacity(0.25) : Color.clear)
                                        )
                                } else {
                                    ZStack {
                                        Circle().fill(colorForItem(item))
                                        Text(String(item.name.prefix(1)))
                                            .foregroundColor(.white)
                                            .font(.headline)
                                    }
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle().fill(isSelected ? Color.accentColor.opacity(0.25) : Color.clear)
                                    )
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                viewModel.delete(item)
                            }
                        }
                        .help("\(item.name) — \(item.url.absoluteString)")
                    }
                }
                .padding(.top, 10)
            }

            Spacer(minLength: 8)

            Button(action: {
                if NSApp.isActive {
                    viewModel.showAddSheet = true
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                    DispatchQueue.main.async {
                        viewModel.showAddSheet = true
                    }
                }
            }) {
                Image(systemName: "plus.circle")
                    .resizable()
                    .frame(width: 25, height: 25)
                    .padding(8)
            }
            .help("Add a new bookmark")
            .sheet(isPresented: $viewModel.showAddSheet) {
                VStack(spacing: 12) {
                    TextField("Name", text: $viewModel.addName)
                    TextField("URL", text: $viewModel.addUrl)
                    HStack {
                        Button("Add") { viewModel.addItem() }
                            .disabled(
                                viewModel.addName.isEmpty ||
                                viewModel.addUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            )
                        Button("Cancel") { viewModel.showAddSheet = false }
                    }
                }
                .padding()
                .frame(width: 300)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(width: 72)
        .background(
            sidebarBackground
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
        .padding(.leading, 8)
        .padding(.vertical, 8)
    }
}
