import SwiftUI

struct DetailModalView: View {
    let item: PasteItem
    let onClose: () -> Void

    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture { onClose() }

                VStack(spacing: 0) {
                    HStack {
                        Text("Detail")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color(nsColor: Constants.textPrimary))
                        Spacer()
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.content, forType: .string)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11))
                                Text("Copy")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(Color(nsColor: Constants.panelBg))
                        .background(Color(nsColor: Constants.accentPrimary))
                        .cornerRadius(Constants.radiusControl)

                        Button(action: { onClose() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(nsColor: Constants.textSecondary))
                                .padding(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(16)
                    .background(Color(nsColor: Constants.surface))

                    Divider().background(Color(nsColor: Constants.dividerColor))

                    ScrollView {
                        Text(item.content)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Color(red: 207/255, green: 207/255, blue: 200/255))
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                            .textSelection(.enabled)
                    }
                    .background(Color(nsColor: Constants.panelBg))
                }
                .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.8)
                .background(
                    RoundedRectangle(cornerRadius: Constants.radiusCard)
                        .fill(Color(nsColor: Constants.surface))
                        .overlay(RoundedRectangle(cornerRadius: Constants.radiusCard)
                            .stroke(Color(nsColor: Constants.neutralBorder)))
                )
                .clipShape(RoundedRectangle(cornerRadius: Constants.radiusCard))
                .scaleEffect(appeared ? 1 : 0.95)
                .opacity(appeared ? 1 : 0)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.2)) { appeared = true } }
    }
}
