import SwiftUI

enum ActionButtonVariant {
    case goldPrimary
    case neutralSecondary
    case quietDanger
}

struct ActionButton: View {
    let label: String
    let variant: ActionButtonVariant
    let isActive: Bool
    let action: () -> Void

    init(label: String, variant: ActionButtonVariant, isActive: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.variant = variant
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .foregroundColor(foregroundColor)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Constants.radiusControl))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.radiusControl)
                .stroke(borderColor, lineWidth: borderWidth)
        )
    }

    private var foregroundColor: Color {
        switch variant {
        case .goldPrimary:
            return Color(nsColor: Constants.panelBg)
        case .neutralSecondary:
            return Color(nsColor: isActive ? Constants.textPrimary : Constants.textSecondary)
        case .quietDanger:
            return isActive ? Color(nsColor: Constants.textPrimary) : Color(nsColor: Constants.dangerText)
        }
    }

    private var backgroundColor: Color {
        switch variant {
        case .goldPrimary:
            return Color(nsColor: Constants.accentPrimary)
        case .neutralSecondary:
            return isActive ? Color(nsColor: Constants.surface) : Color.clear
        case .quietDanger:
            return isActive ? Color(nsColor: Constants.danger) : Color.clear
        }
    }

    private var borderColor: Color {
        switch variant {
        case .goldPrimary:
            return isActive ? Color(nsColor: Constants.focusBorder) : Color.clear
        case .neutralSecondary:
            return Color(nsColor: isActive ? Constants.focusBorder : Constants.neutralBorder)
        case .quietDanger:
            return isActive ? Color.clear : Color(nsColor: Constants.neutralBorder)
        }
    }

    private var borderWidth: CGFloat {
        switch variant {
        case .goldPrimary: return isActive ? 1 : 0
        case .neutralSecondary: return isActive ? 1 : 0.5
        case .quietDanger: return isActive ? 0 : 0.5
        }
    }
}
