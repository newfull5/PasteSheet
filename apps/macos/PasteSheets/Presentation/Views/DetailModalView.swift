import SwiftUI

struct DetailModalView: View {
    let item: PasteItem
    let onClose: () -> Void

    @State private var appeared = false

    private var formattedCreatedAt: String {
        let sqlite = DateFormatter()
        sqlite.locale = Locale(identifier: "en_US_POSIX")
        sqlite.timeZone = TimeZone(identifier: "UTC")
        sqlite.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let display = DateFormatter()
        display.locale = Locale(identifier: "en_US_POSIX")
        display.dateFormat = "yyyy-MM-dd HH:mm"
        if let d = sqlite.date(from: item.createdAt) { return display.string(from: d) }
        return item.createdAt
    }

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

                    Divider().background(Color(nsColor: Constants.dividerColor))

                    HStack(spacing: 8) {
                        Text(formattedCreatedAt)
                        Text("·")
                        Text("\(item.content.count) chars")
                        Spacer()
                    }
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: Constants.textTertiary))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(nsColor: Constants.surface))
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
