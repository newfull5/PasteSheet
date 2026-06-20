import SwiftUI

struct ToggleRow: View {
    let label: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(nsColor: Constants.textPrimary))
                if !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: Constants.textSecondary))
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .tint(Color(nsColor: Constants.accentPrimary))
        }
        .frame(minHeight: 28)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color(nsColor: Constants.surface))
        .overlay(RoundedRectangle(cornerRadius: Constants.radiusCard)
            .stroke(Color(nsColor: Constants.neutralBorder), lineWidth: 1))
        .cornerRadius(Constants.radiusCard)
    }
}
