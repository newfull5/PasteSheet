import SwiftUI

struct ConfirmModalView: View {
    let config: ModalConfig
    let onDismiss: () -> Void
    @State private var inputValue: String
    @State private var appeared = false

    private let accent = Color(nsColor: Constants.accentColor)

    init(config: ModalConfig, onDismiss: @escaping () -> Void) {
        self.config = config
        self.onDismiss = onDismiss
        self._inputValue = State(initialValue: config.inputValue)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 16) {
                Text(config.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(accent)

                Text(config.message)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .lineSpacing(4)

                if config.showInput {
                    TextField("", text: $inputValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.1)))
                }

                HStack {
                    Spacer()
                    Button(config.cancelText) { onDismiss() }
                        .buttonStyle(.plain)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)

                    Button(config.confirmText) {
                        config.onConfirm(config.showInput ? inputValue : nil)
                        onDismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(config.isDanger ? .white : .black)
                    .fontWeight(.bold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(config.isDanger ? Color(nsColor: Constants.modalDangerColor) : accent)
                    .cornerRadius(8)
                    .shadow(color: (config.isDanger ? Color(nsColor: Constants.modalDangerColor) : accent).opacity(0.3),
                            radius: 6, x: 0, y: 4) // 0 4px 12px rgba(...,0.3)
                }
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: Constants.bgContainer)) // rgba(18,18,18,0.98)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1)))
            )
            .scaleEffect(appeared ? 1 : 0.95)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.2)) { appeared = true } }
    }
}
