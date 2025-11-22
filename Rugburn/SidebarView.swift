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
        ZStack(alignment: .trailing) {
            VStack(spacing: 8) {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(viewModel.items) { item in
                            let isSelected = viewModel.selected?.id == item.id

                            Button(action: { viewModel.selected = item }) {
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

                Button(action: { viewModel.showAddSheet = true }) {
                    Image(systemName: "plus.circle")
                        .resizable()
                        .frame(width: 22, height: 22)
                        .padding(6)
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
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .frame(width: 64)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: NSColor.windowBackgroundColor).opacity(0.96))
                    .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 6)
            )

            Rectangle()
                .fill(Color.black.opacity(0.18))
                .frame(width: 1)
                .padding(.vertical, 10)
        }
        .padding(.leading, 6)
        .padding(.vertical, 8)
    }
}
