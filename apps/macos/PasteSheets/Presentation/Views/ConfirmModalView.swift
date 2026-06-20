import SwiftUI

struct ConfirmModalView: View {
    let config: ModalConfig
    let onDismiss: () -> Void
    @State private var inputValue: String
    @State private var appeared = false

    init(config: ModalConfig, onDismiss: @escaping () -> Void) {
        self.config = config
        self.onDismiss = onDismiss
        self._inputValue = State(initialValue: config.inputValue)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    if config.isDanger {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(Color(nsColor: Constants.dangerText))
                    }
                    Text(config.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(nsColor: Constants.textPrimary))
                }

                Text(config.message)
                    .font(.system(size: 13))
                    .foregroundColor(Color(nsColor: Constants.textSecondary))
                    .lineSpacing(4)

                if let preview = config.preview {
                    Text(preview.isEmpty ? "(empty)" : preview)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(nsColor: Constants.textSecondary))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(nsColor: Constants.surface))
                        .overlay(RoundedRectangle(cornerRadius: Constants.radiusControl)
                            .stroke(Color(nsColor: Constants.dividerColor)))
                        .cornerRadius(Constants.radiusControl)
                }

                if config.showInput {
                    TextField("", text: $inputValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .foregroundColor(Color(nsColor: Constants.textPrimary))
                        .padding(8)
                        .background(Color(nsColor: Constants.surface))
                        .cornerRadius(Constants.radiusControl)
                        .overlay(RoundedRectangle(cornerRadius: Constants.radiusControl)
                            .stroke(Color(nsColor: Constants.neutralBorder)))
                }

                HStack(spacing: 8) {
                    Spacer()
                    Button(config.cancelText) { onDismiss() }
                        .buttonStyle(.plain)
                        .foregroundColor(Color(nsColor: Constants.textPrimary))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(nsColor: Constants.surface))
                        .overlay(RoundedRectangle(cornerRadius: Constants.radiusControl)
                            .stroke(Color(nsColor: Constants.neutralBorder)))
                        .cornerRadius(Constants.radiusControl)

                    Button(config.isDanger ? "\(config.confirmText)  ↵" : config.confirmText) {
                        config.onConfirm(config.showInput ? inputValue : nil)
                        onDismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(config.isDanger ? Color(nsColor: Constants.textPrimary) : Color(nsColor: Constants.panelBg))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(config.isDanger ? Color(nsColor: Constants.danger) : Color(nsColor: Constants.accentPrimary))
                    .cornerRadius(Constants.radiusControl)
                }
            }
            .padding(20)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: Constants.radiusCard)
                    .fill(Color(nsColor: Constants.panelBg))
                    .overlay(RoundedRectangle(cornerRadius: Constants.radiusCard)
                        .stroke(Color(nsColor: Constants.neutralBorder)))
            )
            .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
            .scaleEffect(appeared ? 1 : 0.95)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.2)) { appeared = true } }
    }
}
