import SwiftUI

struct HeaderView: View {
    @ObservedObject var vm: AppViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var cursorVisible = true

    private let accent = Color(nsColor: Constants.accentColor)

    func focusSearch() {
        isSearchFocused = true
    }

    var title: String {
        if !vm.searchQuery.isEmpty { return "Search results" }
        switch vm.currentView {
        case .directories: return "PasteSheet"
        case .items: return vm.currentDirectory
        case .settings: return "Settings"
        }
    }

    var showBack: Bool {
        (vm.currentView == .items || vm.currentView == .settings) && vm.searchQuery.isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            if showBack {
                Button(action: { vm.showDirectoryView() }) {
                    Text("◀")
                        .font(.system(size: 16))
                        .foregroundColor(accent)
                }
                .buttonStyle(IconButtonStyle())
            }

            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    Text(title)
                        .font(.system(size: showBack ? 18 : 22, weight: .medium))
                        .foregroundColor(accent)
                        .lineLimit(1)
                    Text("|")
                        .font(.system(size: showBack ? 18 : 22, weight: .medium))
                        .foregroundColor(accent)
                        .opacity(cursorVisible ? 1 : 0)
                        .onAppear {
                            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                                cursorVisible.toggle()
                            }
                        }
                }
                // Show the title (not the search placeholder) whenever the query is
                // empty, even if the field is focused — prevents "Search Anything..."
                // from showing on open.
                .opacity(vm.searchQuery.isEmpty ? 1 : 0)

                TextField("Search Anything...", text: $vm.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: showBack ? 18 : 22, weight: .medium))
                    .foregroundColor(accent)
                    .focused($isSearchFocused)
                    .opacity(vm.searchQuery.isEmpty ? 0 : 1)
                    .onChange(of: vm.searchQuery) { _ in
                        vm.selectedIndex = 0
                    }
                    .onChange(of: vm.isWindowVisible) { visible in
                        if visible { isSearchFocused = false }
                    }
                    .onChange(of: vm.shouldFocusSearch) { focus in
                        if focus {
                            isSearchFocused = true
                            vm.shouldFocusSearch = false
                        }
                    }
            }

            Spacer()

            if vm.currentView != .settings {
                Button(action: { vm.showSettingsView() }) {
                    Text("⚙")
                        .font(.system(size: 20))
                        .foregroundColor(accent.opacity(0.7))
                }
                .buttonStyle(IconButtonStyle())
            }
        }
    }
}

struct IconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white.opacity(0.7))
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed ? Color.white.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
    }
}
