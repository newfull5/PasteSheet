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
    @State private var deleteHovered = false

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
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(nsColor: Constants.textSecondary))
                        .frame(width: 5, height: 5)
                    Text(item.directory)
                        .font(.system(size: 10))
                        .foregroundColor(Color(nsColor: Constants.textSecondary))
                }
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
                deleteButton
            }
            .padding(.top, 8)
        }
    }

    /// Quiet trailing trash icon. Idle = danger-tinted glyph, no fill; it fills
    /// red only on keyboard focus or hover, so the destructive action stays calm
    /// until intent. (Matches the redesign mockup.)
    private var deleteButton: some View {
        let emphasized = activeButtonIndex == 2 || deleteHovered
        return Button(action: onDelete) {
            Image(systemName: "trash")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(emphasized ? Color(nsColor: Constants.textPrimary) : Color(nsColor: Constants.dangerText))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Constants.radiusControl)
                        .fill(emphasized ? Color(nsColor: Constants.danger) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { deleteHovered = $0 }
        .help("Delete")
    }

    @ViewBuilder
    private var editingView: some View {
        Text("CONTENT")
            .font(.system(size: 11))
            .tracking(0.4)
            .foregroundColor(Color(nsColor: Constants.textTertiary))
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

        Text("MEMO · optional")
            .font(.system(size: 11))
            .tracking(0.4)
            .foregroundColor(Color(nsColor: Constants.textTertiary))
            .padding(.top, 2)
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
            Spacer()
            ActionButton(label: "Cancel", variant: .neutralSecondary, action: onCancel)
            ActionButton(label: "Save ⌘↵", variant: .goldPrimary, action: onSave)
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
        // Matched runs get a faint gold-tint chip + bold, per the redesign mockup.
        // AttributedString lets us set a per-run backgroundColor (a plain Text can't).
        let chip = Color(red: 199/255, green: 202/255, blue: 70/255).opacity(0.18)
        var attr = AttributedString()
        var current = lower.startIndex
        while let range = lower.range(of: query, range: current..<lower.endIndex) {
            if current < range.lowerBound {
                var seg = AttributedString(String(text[current..<range.lowerBound]))
                seg.foregroundColor = baseColor
                attr += seg
            }
            var match = AttributedString(String(text[range]))
            match.foregroundColor = Color(nsColor: Constants.textPrimary)
            match.backgroundColor = chip
            match.inlinePresentationIntent = .stronglyEmphasized
            attr += match
            current = range.upperBound
        }
        if current < lower.endIndex {
            var seg = AttributedString(String(text[current..<lower.endIndex]))
            seg.foregroundColor = baseColor
            attr += seg
        }
        return Text(attr)
    }

    private func formatDate(_ str: String) -> String {
        let display = DateFormatter()
        display.locale = Locale(identifier: "en_US_POSIX")
        display.dateFormat = "MMM d, h:mm a"

        // SQLite CURRENT_TIMESTAMP is stored as "yyyy-MM-dd HH:mm:ss" in UTC.
        let sqlite = DateFormatter()
        sqlite.locale = Locale(identifier: "en_US_POSIX")
        sqlite.timeZone = TimeZone(identifier: "UTC")
        sqlite.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = sqlite.date(from: str) {
            return display.string(from: date)
        }

        // Fallback: ISO8601 (with or without fractional seconds).
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: str) {
            return display.string(from: date)
        }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: str) {
            return display.string(from: date)
        }

        return str
    }
}

