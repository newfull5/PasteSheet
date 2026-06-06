import SwiftUI

struct DetailModalView: View {
    let item: PasteItem
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Detail View")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.content, forType: .string)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.black)
                    .fontWeight(.bold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.yellow)
                    .cornerRadius(6)

                    Button("Close") { onClose() }
                        .buttonStyle(.plain)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(6)
                }
                .padding(16)
                .background(Color.white.opacity(0.05))

                Divider().opacity(0.1)

                // Content
                ScrollView {
                    Text(item.content)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(24)
                        .textSelection(.enabled)
                }
            }
            .frame(width: 500, height: 400)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: NSColor(white: 0.1, alpha: 1)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
            )
        }
    }
}
