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

    private let accent = Color(nsColor: Constants.accentColor)
    private let subText = Color(nsColor: Constants.subTextColor)

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? accent : subText.opacity(0.4))
                .frame(width: 4)
                .frame(maxHeight: isSelected ? .infinity : 16)
                .shadow(color: isSelected ? accent : .clear, radius: 4, x: 0, y: 0) // --shadow-glow: 0 0 8px accent
                .padding(.trailing, 12)

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
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? accent.opacity(0.08) : Color.clear)
        )
    }

    @ViewBuilder
    private var normalView: some View {
        // Header: memo + folder label
        HStack {
            if let memo = item.memo, !memo.isEmpty {
                highlightedText(memo, baseColor: Color(nsColor: Constants.memoColor))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
            }
            Spacer()
            if showFolderLabel {
                Text(item.directory)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(4)
            }
        }

        // Content
        highlightedText(snippetForSearch(item.content), baseColor: isSelected ? .white : .white.opacity(0.7))
            .font(.system(size: 14))
            .lineLimit(isSelected ? 15 : 1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)

        // Selected: meta + actions
        if isSelected {
            Text(formatDate(item.createdAt))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(subText.opacity(0.6)) // var(--color-text-sub) opacity 0.6
                .padding(.top, 8)

            HStack(spacing: 8) {
                ActionButton(label: "Paste", isActive: activeButtonIndex == 0, isDanger: false, action: onPaste)
                ActionButton(label: "Edit", isActive: activeButtonIndex == 1, isDanger: false, action: onEdit)
                ActionButton(label: "Delete", isActive: activeButtonIndex == 2, isDanger: true, action: onDelete)
            }
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var editingView: some View {
        TextField("Memo", text: $editMemo)
            .textFieldStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(accent)
            .padding(8)
            .background(accent.opacity(0.05))
            .cornerRadius(4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(accent.opacity(0.2)))

        TextEditor(text: $editContent)
            .font(.system(size: 14))
            .foregroundColor(.white)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 120)
            .padding(8)
            .background(Color.white.opacity(0.03))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(accent.opacity(0.2)))

        HStack(spacing: 8) {
            ActionButton(label: "Save ⌘↵", isActive: true, isDanger: false, action: onSave)
            ActionButton(label: "Cancel", isActive: false, isDanger: false, action: onCancel)
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
                .foregroundColor(Color(nsColor: Constants.accentColor))
                .bold()
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
            display.dateStyle = .medium
            display.timeStyle = .short
            return display.string(from: date)
        }
        return str
    }
}

struct ActionButton: View {
    let label: String
    let isActive: Bool
    let isDanger: Bool
    let action: () -> Void

    private let accent = Color(nsColor: Constants.accentColor)

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .foregroundColor(foregroundColor)
        .background(backgroundColor)
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var foregroundColor: Color {
        if isActive && isDanger { return .white }
        if isActive { return .black }
        return Color(nsColor: Constants.subTextColor)
    }

    private var backgroundColor: Color {
        if isActive && isDanger { return Color(nsColor: Constants.dangerColor) }
        if isActive { return accent }
        return Color.white.opacity(0.05)
    }

    private var borderColor: Color {
        if isActive && isDanger { return Color(nsColor: Constants.dangerColor) }
        if isActive { return .clear }
        return Color.white.opacity(0.1)
    }
}
