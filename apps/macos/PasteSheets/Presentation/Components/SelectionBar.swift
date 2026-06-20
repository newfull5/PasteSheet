import SwiftUI

struct SelectionBar: View {
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(isSelected
                ? Color(nsColor: Constants.accentPrimary)
                : Color(nsColor: Constants.neutralBorder))
            .frame(width: 3)
    }
}
