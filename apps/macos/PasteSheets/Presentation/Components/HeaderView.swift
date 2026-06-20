import SwiftUI

struct HeaderView: View {
    @ObservedObject var vm: AppViewModel
    @FocusState private var isSearchFocused: Bool

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
                        .foregroundColor(Color(nsColor: Constants.textSecondary))
                }
                .buttonStyle(IconButtonStyle())
            }

            ZStack(alignment: .leading) {
                Text(title)
                    .font(.system(size: showBack ? 17 : 20, weight: .medium))
                    .foregroundColor(Color(nsColor: Constants.textPrimary))
                    .lineLimit(1)
                    .opacity(isSearchFocused || !vm.searchQuery.isEmpty ? 0 : 1)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14))
                        .foregroundColor(Color(nsColor: Constants.textTertiary))
                    TextField("Search clipboard…", text: $vm.searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .foregroundColor(Color(nsColor: Constants.textPrimary))
                        .focused($isSearchFocused)
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
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: Constants.radiusControl)
                        .fill(Color(nsColor: Constants.surface))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.radiusControl)
                        .stroke(Color(nsColor: isSearchFocused ? Constants.focusBorder : Constants.neutralBorder),
                                lineWidth: isSearchFocused ? 1.5 : 1)
                )
                .opacity(isSearchFocused || !vm.searchQuery.isEmpty ? 1 : 0)
            }

            Spacer()

            if vm.currentView != .settings {
                Button(action: { vm.showSettingsView() }) {
                    Text("⚙")
                        .font(.system(size: 20))
                        .foregroundColor(Color(nsColor: Constants.textTertiary))
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.white.opacity(0.1) : Color.clear)
            )
            .contentShape(Rectangle())
    }
}
