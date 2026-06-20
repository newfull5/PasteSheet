import SwiftUI

struct DirectoryListView: View {
    @ObservedObject var vm: AppViewModel
    private var isCreating: Bool {
        get { vm.isCreatingFolder }
        nonmutating set { vm.isCreatingFolder = newValue }
    }
    @State private var newFolderName = ""
    @FocusState private var folderFieldFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(vm.filteredDirectories.enumerated()), id: \.element.id) { index, dir in
                        DirectoryRow(
                            directory: dir,
                            isSelected: vm.selectedIndex == index,
                            onOpen: { vm.showItemView(directoryName: dir.name) }
                        )
                        .id(index)
                        .contextMenu {
                            if dir.name != Constants.defaultDirectory {
                                Button("Rename") { vm.renameDirectory(oldName: dir.name) }
                                Button("Delete") { vm.deleteDirectory(name: dir.name) }
                            }
                        }
                    }

                    // New Folder button
                    newFolderRow
                        .id(vm.filteredDirectories.count)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .onChange(of: vm.selectedIndex) { idx in
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
            .onChange(of: vm.shouldStartFolderCreation) { start in
                if start {
                    isCreating = true
                    folderFieldFocused = true
                    vm.shouldStartFolderCreation = false
                }
            }
            .onChange(of: vm.isCreatingFolder) { creating in
                if !creating {
                    newFolderName = ""
                }
            }
        }
    }

    @ViewBuilder
    private var newFolderRow: some View {
        let isSelected = vm.selectedIndex == vm.filteredDirectories.count

        HStack {
            if isCreating {
                TextField("Folder name…", text: $newFolderName, onCommit: {
                    let name = newFolderName.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { vm.createDirectory(name: name) }
                    isCreating = false
                    newFolderName = ""
                })
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(Color(nsColor: Constants.textPrimary))
                .focused($folderFieldFocused)
                .padding(8)
                .background(Color(nsColor: Constants.surface))
                .cornerRadius(Constants.radiusControl)
                .overlay(RoundedRectangle(cornerRadius: Constants.radiusControl)
                    .stroke(Color(nsColor: Constants.focusBorder), lineWidth: 1))
                .onChange(of: folderFieldFocused) { focused in
                    if !focused {
                        isCreating = false
                        newFolderName = ""
                    }
                }
                .onExitCommand {
                    isCreating = false
                    newFolderName = ""
                }
            } else {
                HStack(spacing: 12) {
                    Text("＋")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(nsColor: Constants.textTertiary))
                    Text("New folder")
                        .font(.system(size: 14))
                        .foregroundColor(Color(nsColor: Constants.textTertiary))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: Constants.radiusControl)
            .fill(isSelected ? Color(nsColor: Constants.surface) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: Constants.radiusControl)
            .stroke(Color(nsColor: Constants.neutralBorder), style: StrokeStyle(lineWidth: 1, dash: [5])))
        .contentShape(Rectangle())
        .onTapGesture { isCreating = true }
    }
}
