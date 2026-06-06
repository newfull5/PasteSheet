import SwiftUI

struct DetailModalView: View {
    let item: PasteItem
    let onClose: () -> Void

    @State private var appeared = false
    private let accent = Color(nsColor: Constants.accentColor)

    var body: some View {
        GeometryReader { geo in
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
                        .background(accent)
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

                    Divider().background(Color.white.opacity(0.1))

                    // Content (bg #1a1a1a)
                    ScrollView {
                        Text(item.content)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                            .textSelection(.enabled)
                    }
                    .background(Color(nsColor: Constants.detailContentBg))
                }
                .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: Constants.detailModalBg))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .scaleEffect(appeared ? 1 : 0.95)
                .opacity(appeared ? 1 : 0)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.2)) { appeared = true } }
    }
}
