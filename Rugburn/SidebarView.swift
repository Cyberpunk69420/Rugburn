import SwiftUI
import Combine

struct SidebarView: View {
    @ObservedObject var viewModel: SidebarViewModel

    let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .yellow, .teal, .indigo]

    func colorForItem(_ item: WebAppItem) -> Color {
        let idx = abs(item.name.hashValue) % colors.count
        return colors[idx]
    }

    var body: some View {
        VStack {
            ScrollView {
                ForEach(viewModel.items) { item in
                    Button(action: {
                        viewModel.selected = item
                    }) {
                        ZStack {
                            Circle().fill(colorForItem(item))
                            Text(String(item.name.prefix(1)))
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .frame(width: 32, height: 32)
                        .padding(8)
                        .background(
                            viewModel.selected?.id == item.id
                            ? Color.accentColor.opacity(0.2)
                            : Color.clear
                        )
                        .clipShape(Circle())
                        .shadow(radius: 4)
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
