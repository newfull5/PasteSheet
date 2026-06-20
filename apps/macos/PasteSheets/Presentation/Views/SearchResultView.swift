import SwiftUI

struct SearchResultView: View {
    @ObservedObject var vm: AppViewModel

    var dirs: [DirectoryInfo] { vm.filteredDirectories }
    var items: [PasteItem] { vm.filteredItems }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if !(dirs.isEmpty && items.isEmpty) {
                        (Text("\(dirs.count + items.count) results")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(nsColor: Constants.textPrimary))
                         + Text(" for \"\(vm.searchQuery)\"")
                            .font(.system(size: 13))
                            .foregroundColor(Color(nsColor: Constants.textSecondary)))
                            .lineLimit(1)
                            .padding(.leading, 8)
                            .padding(.top, 8)
                            .padding(.bottom, 2)
                    }

                    if !dirs.isEmpty {
                        sectionHeader("Folders", count: dirs.count)
                        ForEach(Array(dirs.enumerated()), id: \.element.id) { index, dir in
                            DirectoryRow(
                                directory: dir,
                                isSelected: vm.selectedIndex == index,
                                onOpen: { vm.showItemView(directoryName: dir.name) }
                            )
                            .id(dir.id)
                        }
                    }

                    if !items.isEmpty {
                        sectionHeader("Items", count: items.count)
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
                            .id(item.id)
                            .onTapGesture { vm.selectedIndex = globalIdx }
                        }
                    }

                    if dirs.isEmpty && items.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 28))
                                .foregroundColor(Color(nsColor: Constants.textTertiary))
                            Text("No matches")
                                .font(.system(size: 15))
                                .foregroundColor(Color(nsColor: Constants.textSecondary))
                            Text("Nothing found for \"\(vm.searchQuery)\"")
                                .font(.system(size: 13))
                                .foregroundColor(Color(nsColor: Constants.textTertiary))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .onChange(of: vm.selectedIndex) { idx in
                withAnimation(.easeInOut(duration: 0.15)) {
                    if idx < dirs.count {
                        proxy.scrollTo(dirs[idx].id, anchor: .center)
                    } else {
                        let itemIdx = idx - dirs.count
                        if itemIdx < items.count {
                            proxy.scrollTo(items[itemIdx].id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        Text("\(title) (\(count))")
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .foregroundColor(Color(nsColor: Constants.textTertiary))
            .tracking(0.8)
            .padding(.leading, 8)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
}
