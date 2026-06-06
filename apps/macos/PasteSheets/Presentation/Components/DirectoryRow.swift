import SwiftUI

struct DirectoryRow: View {
    let directory: DirectoryInfo
    let isSelected: Bool
    let onOpen: () -> Void

    private let accent = Color(nsColor: Constants.accentColor)
    private let subText = Color(nsColor: Constants.subTextColor)

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? accent : subText.opacity(0.4))
                .frame(width: 4, height: 18)
                .shadow(color: isSelected ? accent : .clear, radius: 4, x: 0, y: 0) // glow
                .padding(.trailing, 12)

            Text(directory.name)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            Text("\(directory.count)")
                .font(.system(size: 12))
                .foregroundColor(subText)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08))
                .cornerRadius(10)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? accent.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture { onOpen() }
    }
}
