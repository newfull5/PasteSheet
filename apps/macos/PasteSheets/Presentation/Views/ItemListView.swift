import SwiftUI

struct ItemListView: View {
    @ObservedObject var vm: AppViewModel
    private var isCreating: Bool {
        get { vm.isCreatingItem }
        nonmutating set { vm.isCreatingItem = newValue }
    }
    @State private var newMemo = ""
    @State private var newContent = ""
    @FocusState private var memoFieldFocused: Bool
    @FocusState private var contentFieldFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(vm.filteredItems.enumerated()), id: \.element.id) { index, item in
                        HistoryItemRow(
                            item: item,
                            isSelected: vm.selectedIndex == index,
                            activeButtonIndex: vm.selectedIndex == index ? vm.buttonFocusIndex : -1,
                            isEditing: vm.editingItemId == item.id,
                            editContent: $vm.editContent,
                            editMemo: $vm.editMemo,
                            onPaste: { vm.pasteItem(item) },
                            onEdit: { vm.startEdit(item) },
                            onDelete: { vm.deleteItem(id: item.id) },
                            onSave: { vm.saveEdit() },
                            onCancel: { vm.cancelEdit() }
                        )
                        .id(item.id)
                        .onTapGesture { vm.selectedIndex = index }

                        if vm.selectedIndex != index && vm.selectedIndex != index + 1
                            && index < vm.filteredItems.count - 1 {
                            Rectangle()
                                .fill(Color(nsColor: Constants.dividerColor))
                                .frame(height: 0.5)
                                .padding(.horizontal, 8)
                        }
                    }

                    newItemRow
                        .id("new-item-row")

                    if vm.filteredItems.isEmpty && !isCreating {
                        Text("No items found in this folder")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .safeAreaInset(edge: .bottom) {
                Text("↵ paste · ⌘N new · ⌘⌫ delete")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: Constants.textTertiary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(nsColor: Constants.bgContainer))
            }
            .onChange(of: vm.selectedIndex) { idx in
                withAnimation(.easeInOut(duration: 0.15)) {
                    let items = vm.filteredItems
                    if idx >= items.count {
                        proxy.scrollTo("new-item-row", anchor: .center)
                    } else {
                        proxy.scrollTo(items[idx].id, anchor: .center)
                    }
                }
            }
            .onChange(of: vm.shouldStartItemCreation) { start in
                if start {
                    isCreating = true
                    contentFieldFocused = true
                    vm.shouldStartItemCreation = false
                }
            }
            .onChange(of: vm.shouldSaveNewItem) { save in
                if save {
                    vm.shouldSaveNewItem = false
                    let c = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !c.isEmpty else { return }  // empty content: keep the form open
                    vm.createItem(content: c, memo: newMemo.isEmpty ? nil : newMemo)
                    isCreating = false
                    newMemo = ""
                    newContent = ""
                }
            }
        }
    }

    @ViewBuilder
    private var newItemRow: some View {
        let isSelected = vm.selectedIndex == vm.filteredItems.count

        VStack(alignment: .leading, spacing: 8) {
            if isCreating {
                Text("CONTENT")
                    .font(.system(size: 11))
                    .tracking(0.4)
                    .foregroundColor(Color(nsColor: Constants.textTertiary))
                TextEditor(text: $newContent)
                    .font(.system(size: 14))
                    .foregroundColor(Color(nsColor: Constants.textPrimary))
                    .scrollContentBackground(.hidden)
                    .focused($contentFieldFocused)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(nsColor: Constants.surface))
                    .cornerRadius(Constants.radiusControl)
                    .overlay(RoundedRectangle(cornerRadius: Constants.radiusControl)
                        .stroke(Color(nsColor: Constants.neutralBorder), lineWidth: 0.5))

                Text("MEMO · optional")
                    .font(.system(size: 11))
                    .tracking(0.4)
                    .foregroundColor(Color(nsColor: Constants.textTertiary))
                    .padding(.top, 2)
                TextField("Add a note…", text: $newMemo)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(nsColor: Constants.textPrimary))
                    .focused($memoFieldFocused)
                    .padding(8)
                    .background(Color(nsColor: Constants.surface))
                    .cornerRadius(Constants.radiusControl)
                    .overlay(RoundedRectangle(cornerRadius: Constants.radiusControl)
                        .stroke(Color(nsColor: Constants.neutralBorder), lineWidth: 0.5))

                HStack(spacing: 8) {
                    Spacer()
                    ActionButton(label: "Cancel", variant: .neutralSecondary) {
                        isCreating = false
                        newMemo = ""
                        newContent = ""
                    }
                    ActionButton(label: "Save ⌘↵", variant: .goldPrimary) {
                        let c = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !c.isEmpty else { return }  // empty content: keep the form open
                        vm.createItem(content: c, memo: newMemo.isEmpty ? nil : newMemo)
                        isCreating = false
                        newMemo = ""
                        newContent = ""
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Text("＋")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(nsColor: Constants.textTertiary))
                    Text("New item")
                        .font(.system(size: 14))
                        .foregroundColor(Color(nsColor: Constants.textTertiary))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Constants.radiusControl)
            .fill(isSelected ? Color(nsColor: Constants.surface) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: Constants.radiusControl)
            .stroke(Color(nsColor: Constants.neutralBorder), style: StrokeStyle(lineWidth: 1, dash: [5])))
        .contentShape(Rectangle())
        .onTapGesture { isCreating = true; contentFieldFocused = true }
    }
}
