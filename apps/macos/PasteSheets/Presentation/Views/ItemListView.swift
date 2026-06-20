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
                        .id(index)
                        .onTapGesture { vm.selectedIndex = index }
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
            .onChange(of: vm.selectedIndex) { idx in
                withAnimation(.easeInOut(duration: 0.15)) {
                    if idx == vm.filteredItems.count {
                        proxy.scrollTo("new-item-row", anchor: .center)
                    } else {
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
            }
            .onChange(of: vm.shouldStartItemCreation) { start in
                if start {
                    isCreating = true
                    memoFieldFocused = true
                    vm.shouldStartItemCreation = false
                }
            }
            .onChange(of: vm.shouldSaveNewItem) { save in
                if save {
                    let c = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !c.isEmpty {
                        vm.createItem(content: c, memo: newMemo.isEmpty ? nil : newMemo)
                    }
                    isCreating = false
                    newMemo = ""
                    newContent = ""
                    vm.shouldSaveNewItem = false
                }
            }
        }
    }

    @ViewBuilder
    private var newItemRow: some View {
        let isSelected = vm.selectedIndex == vm.filteredItems.count

        VStack(alignment: .leading, spacing: 8) {
            if isCreating {
                TextEditor(text: $newContent)
                    .font(.system(size: 14))
                    .foregroundColor(Color(nsColor: Constants.textPrimary))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(nsColor: Constants.surface))
                    .cornerRadius(Constants.radiusControl)
                    .overlay(RoundedRectangle(cornerRadius: Constants.radiusControl)
                        .stroke(Color(nsColor: Constants.neutralBorder), lineWidth: 0.5))

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
                    ActionButton(label: "Save ⌘↵", variant: .goldPrimary) {
                        let c = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !c.isEmpty {
                            vm.createItem(content: c, memo: newMemo.isEmpty ? nil : newMemo)
                        }
                        isCreating = false
                        newMemo = ""
                        newContent = ""
                    }
                    ActionButton(label: "Cancel", variant: .neutralSecondary) {
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
        .onTapGesture { isCreating = true; memoFieldFocused = true }
    }
}
