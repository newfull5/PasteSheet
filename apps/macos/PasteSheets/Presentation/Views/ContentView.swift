import SwiftUI

struct ContentView: View {
    @ObservedObject var vm: AppViewModel

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HeaderView(vm: vm)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                Divider().opacity(0.1)

                Group {
                    if !vm.searchQuery.isEmpty {
                        SearchResultView(vm: vm)
                    } else {
                        switch vm.currentView {
                        case .directories:
                            DirectoryListView(vm: vm)
                        case .items:
                            ItemListView(vm: vm)
                        case .settings:
                            SettingsView(vm: vm)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.bottom, 12)

            if let modal = vm.modalConfig {
                ConfirmModalView(config: modal) {
                    vm.modalConfig = nil
                }
            }

            if let item = vm.detailItem {
                DetailModalView(item: item) {
                    vm.detailItem = nil
                }
            }

            // Resize handle
            VStack {
                Spacer()
                ResizeHandle(vm: vm)
            }
        }
        .frame(width: Constants.windowWidth)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: Constants.bgContainer))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ResizeHandle: View {
    @ObservedObject var vm: AppViewModel
    @State private var isDragging = false
    @State private var startY: CGFloat = 0
    @State private var startHeight: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .frame(height: 12)
            .overlay(
                Capsule()
                    .fill(Color.white.opacity(isDragging ? 0.3 : 0.1))
                    .frame(width: 32, height: 3)
            )
            .contentShape(Rectangle())
            .cursor(.resizeUpDown)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            startHeight = vm.panel?.frame.height ?? 800
                        }
                        let delta = -value.translation.height
                        let newHeight = min(max(startHeight + delta, Constants.windowMinHeight), Constants.windowMaxHeight)
                        if let panel = vm.panel {
                            var frame = panel.frame
                            frame.size.height = newHeight
                            panel.setFrame(frame, display: true)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        if let panel = vm.panel as? MainPanel {
                            panel.saveHeight()
                        }
                    }
            )
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}
