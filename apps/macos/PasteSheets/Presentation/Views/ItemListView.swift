import SwiftUI

struct ItemListView: View {
    @ObservedObject var vm: AppViewModel
    @State private var isCreating = false
    @State private var newMemo = ""
    @State private var newContent = ""

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
                        .id(vm.filteredItems.count)

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
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private var newItemRow: some View {
        let isSelected = vm.selectedIndex == vm.filteredItems.count

        VStack(alignment: .leading, spacing: 8) {
            if isCreating {
                TextField("Memo (Optional)...", text: $newMemo)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(nsColor: Constants.accentColor))
                    .padding(8)
                    .background(Color(nsColor: Constants.accentColor).opacity(0.05))
                    .cornerRadius(4)

                TextEditor(text: $newContent)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: Constants.accentColor).opacity(0.2)))

                HStack(spacing: 8) {
                    ActionButton(label: "Save", isActive: true, isDanger: false) {
                        let c = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !c.isEmpty {
                            vm.createItem(content: c, memo: newMemo.isEmpty ? nil : newMemo)
                        }
                        isCreating = false
                        newMemo = ""
                        newContent = ""
                    }
                    ActionButton(label: "Cancel", isActive: false, isDanger: false) {
                        isCreating = false
                        newMemo = ""
                        newContent = ""
                    }
                }
            } else {
                HStack(spacing: 12) {
                    Text("＋")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(nsColor: Constants.accentColor))
                    Text("New Item")
                        .font(.system(size: 14))
                        .foregroundColor(Color(nsColor: Constants.accentColor).opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? Color(nsColor: Constants.accentColor).opacity(0.08) : Color.clear))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.05), style: StrokeStyle(lineWidth: 1, dash: [5])))
        .contentShape(Rectangle())
        .onTapGesture { isCreating = true }
    }
}
