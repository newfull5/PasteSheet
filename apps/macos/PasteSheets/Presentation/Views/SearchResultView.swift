import SwiftUI

struct SearchResultView: View {
    @ObservedObject var vm: AppViewModel

    var dirs: [DirectoryInfo] { vm.filteredDirectories }
    var items: [PasteItem] { vm.filteredItems }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if !dirs.isEmpty {
                        sectionHeader("Folders")
                        ForEach(Array(dirs.enumerated()), id: \.element.id) { index, dir in
                            DirectoryRow(
                                directory: dir,
                                isSelected: vm.selectedIndex == index,
                                onOpen: { vm.showItemView(directoryName: dir.name) }
                            )
                            .id(index)
                        }
                    }

                    if !items.isEmpty {
                        sectionHeader("Items")
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            let globalIdx = dirs.count + index
                            HistoryItemRow(
                                item: item,
                                isSelected: vm.selectedIndex == globalIdx,
                                activeButtonIndex: vm.selectedIndex == globalIdx ? vm.buttonFocusIndex : -1,
                                isEditing: vm.editingItemId == item.id,
                                showFolderLabel: true,
                                searchQuery: vm.searchQuery,
                                editContent: $vm.editContent,
                                editMemo: $vm.editMemo,
                                onPaste: { vm.pasteItem(item) },
                                onEdit: { vm.startEdit(item) },
                                onDelete: { vm.deleteItem(id: item.id) },
                                onSave: { vm.saveEdit() },
                                onCancel: { vm.cancelEdit() }
                            )
                            .id(globalIdx)
                            .onTapGesture { vm.selectedIndex = globalIdx }
                        }
                    }

                    if dirs.isEmpty && items.isEmpty {
                        Text("No matches found for your search.")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .onChange(of: vm.selectedIndex) { idx in
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .textCase(.uppercase)
            .foregroundColor(.white.opacity(0.4))
            .tracking(1)
            .padding(.leading, 8)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
}
