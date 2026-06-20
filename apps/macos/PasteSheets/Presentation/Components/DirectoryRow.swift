import SwiftUI

struct DirectoryRow: View {
    let directory: DirectoryInfo
    let isSelected: Bool
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            SelectionBar(isSelected: isSelected)
                .frame(height: 18)
                .padding(.trailing, 10)

            Image(systemName: "folder")
                .font(.system(size: 14))
                .foregroundColor(Color(nsColor: isSelected ? Constants.accentPrimary : Constants.textTertiary))
                .frame(width: 20)
                .padding(.trailing, 10)

            Text(directory.name)
                .font(.system(size: 15))
                .foregroundColor(Color(nsColor: Constants.textPrimary))
                .lineLimit(1)

            Spacer()

            Text("\(directory.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(nsColor: Constants.textTertiary))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: Constants.radiusControl)
                .fill(isSelected ? Color(nsColor: Constants.surface) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onOpen() }
    }
}
