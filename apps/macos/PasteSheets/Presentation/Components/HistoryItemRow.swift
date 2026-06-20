import SwiftUI

struct HistoryItemRow: View {
    let item: PasteItem
    let isSelected: Bool
    let activeButtonIndex: Int
    let isEditing: Bool
    let showFolderLabel: Bool
    @Binding var editContent: String
    @Binding var editMemo: String
    let onPaste: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let searchQuery: String

    init(item: PasteItem, isSelected: Bool, activeButtonIndex: Int = -1,
         isEditing: Bool = false, showFolderLabel: Bool = false,
         searchQuery: String = "",
         editContent: Binding<String>, editMemo: Binding<String>,
         onPaste: @escaping () -> Void, onEdit: @escaping () -> Void,
         onDelete: @escaping () -> Void, onSave: @escaping () -> Void,
         onCancel: @escaping () -> Void) {
        self.item = item
        self.isSelected = isSelected
        self.activeButtonIndex = activeButtonIndex
        self.isEditing = isEditing
        self.showFolderLabel = showFolderLabel
        self._editContent = editContent
        self._editMemo = editMemo
        self.onPaste = onPaste
        self.onEdit = onEdit
        self.onDelete = onDelete
        self.onSave = onSave
        self.onCancel = onCancel
        self.searchQuery = searchQuery
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            SelectionBar(isSelected: isSelected)
                .padding(.trailing, 8)

            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    editingView
                } else {
                    normalView
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: Constants.radiusCard)
                .fill(isSelected ? Color(nsColor: Constants.surface) : Color.clear)
        )
    }

    @ViewBuilder
    private var normalView: some View {
        HStack {
            if let memo = item.memo, !memo.isEmpty {
                highlightedText(memo, baseColor: Color(nsColor: Constants.textPrimary))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            Spacer()
            if showFolderLabel {
                Text(item.directory)
                    .font(.system(size: 10))
                    .foregroundColor(Color(nsColor: Constants.textSecondary))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color(nsColor: Constants.surface))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(nsColor: Constants.neutralBorder), lineWidth: 0.5))
                    .cornerRadius(4)
            }
        }

        highlightedText(snippetForSearch(item.content),
                        baseColor: Color(nsColor: isSelected ? Constants.textPrimary : Constants.textSecondary))
            .font(.system(size: 14))
            .lineLimit(isSelected ? 15 : 1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)

        if isSelected {
            Text(formatDate(item.createdAt))
                .font(.system(size: 11))
                .foregroundColor(Color(nsColor: Constants.textTertiary))
                .padding(.top, 8)

            HStack(spacing: 8) {
                ActionButton(label: "Paste", variant: .goldPrimary, isActive: activeButtonIndex == 0, action: onPaste)
                ActionButton(label: "Edit", variant: .neutralSecondary, isActive: activeButtonIndex == 1, action: onEdit)
                Spacer()
                ActionButton(label: "Delete", variant: .quietDanger, isActive: activeButtonIndex == 2, action: onDelete)
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var editingView: some View {
        TextEditor(text: $editContent)
            .font(.system(size: 14))
            .foregroundColor(Color(nsColor: Constants.textPrimary))
            .scrollContentBackground(.hidden)
            .frame(minHeight: 120)
            .padding(8)
            .background(Color(nsColor: Constants.surface))
            .cornerRadius(Constants.radiusControl)
            .overlay(RoundedRectangle(cornerRadius: Constants.radiusControl)
                .stroke(Color(nsColor: Constants.neutralBorder), lineWidth: 0.5))

        TextField("Add a note…", text: $editMemo)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Color(nsColor: Constants.textPrimary))
            .padding(8)
            .background(Color(nsColor: Constants.surface))
            .cornerRadius(Constants.radiusControl)
            .overlay(RoundedRectangle(cornerRadius: Constants.radiusControl)
                .stroke(Color(nsColor: Constants.neutralBorder), lineWidth: 0.5))

        HStack(spacing: 8) {
            ActionButton(label: "Save ⌘↵", variant: .goldPrimary, action: onSave)
            ActionButton(label: "Cancel", variant: .neutralSecondary, action: onCancel)
        }
    }

    private func snippetForSearch(_ text: String) -> String {
        guard !searchQuery.isEmpty else { return text }
        let lower = text.lowercased()
        let query = searchQuery.lowercased()
        guard let range = lower.range(of: query) else { return text }
        let matchStart = lower.distance(from: lower.startIndex, to: range.lowerBound)
        if matchStart <= 60 { return text }
        let snippetStart = text.index(text.startIndex, offsetBy: max(0, matchStart - 20))
        return "…" + String(text[snippetStart...])
    }

    private func highlightedText(_ text: String, baseColor: Color) -> Text {
        guard !searchQuery.isEmpty else {
            return Text(text).foregroundColor(baseColor)
        }
        let lower = text.lowercased()
        let query = searchQuery.lowercased()
        var result = Text("")
        var current = lower.startIndex
        while let range = lower.range(of: query, range: current..<lower.endIndex) {
            if current < range.lowerBound {
                result = result + Text(text[current..<range.lowerBound]).foregroundColor(baseColor)
            }
            result = result + Text(text[range])
                .foregroundColor(Color(nsColor: Constants.textPrimary))
                .fontWeight(.semibold)
            current = range.upperBound
        }
        if current < lower.endIndex {
            result = result + Text(text[current..<lower.endIndex]).foregroundColor(baseColor)
        }
        return result
    }

    private func formatDate(_ str: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: str) {
            let display = DateFormatter()
            display.dateFormat = "MMM d, h:mm a"
            return display.string(from: date)
        }
        return str
    }
}

