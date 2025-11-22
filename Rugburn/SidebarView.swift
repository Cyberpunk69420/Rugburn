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

    var body: some View {
        VStack {
            ScrollView {
                ForEach(viewModel.items) { item in
                    Button(action: {
                        viewModel.selected = item
                    }) {
                        let isSelected = viewModel.selected?.id == item.id

                        Group {
                            if let nsImage = faviconImage(for: item) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .padding(6)
                                    .background(
                                        isSelected
                                        ? Color.accentColor.opacity(0.2)
                                        : Color.clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .shadow(radius: 4)
                            } else {
                                ZStack {
                                    Circle().fill(colorForItem(item))
                                    Text(String(item.name.prefix(1)))
                                        .foregroundColor(.white)
                                        .font(.headline)
                                }
                                .frame(width: 32, height: 32)
                                .padding(8)
                                .background(
                                    isSelected
                                    ? Color.accentColor.opacity(0.2)
                                    : Color.clear
                                )
                                .clipShape(Circle())
                                .shadow(radius: 4)
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
            Spacer()

            Button(action: { viewModel.showAddSheet = true }) {
                Image(systemName: "plus.circle")
                    .resizable()
                    .frame(width: 32, height: 32)
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
        .frame(width: 80)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(16)
        .shadow(radius: 8)
    }
}
