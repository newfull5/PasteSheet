# PasteSheet

**PasteSheet: A smart clipboard manager designed to make pasting easier**  
Keep your clipboard history organized, editable, and instantly accessible. Built with Rust & Tauri for maximum performance.

> ⚠️ **Beta Notice:** This project is currently in **Beta**. If you experience any issues or inconveniences, please report them in the [Issues](https://github.com/newfull5/PasteSheets/issues) section.

<video src="https://github.com/user-attachments/assets/89d47103-148d-4ad7-9dca-60e520867989" width="100%" autoplay loop muted playsinline></video>

>  currently supports **macOS**. (Windows version is under developing!)

## Installation

### Method 1: Homebrew (Recommended)
You can install PasteSheet via Homebrew by tapping the official repository:

```bash
# 1. Tap the repository
brew tap newfull5/tap

# 2. Install the app
brew install --cask pastesheet
```

### Method 2: Direct Download
1. Download the latest `.dmg` file:
   [**Download PasteSheet v0.1.0-beta (macOS ARM64)**](https://github.com/newfull5/PasteSheets/releases/download/v0.1.0-beta/PasteSheet_0.1.0_aarch64.dmg)
2. Open the `.dmg` file and drag **PasteSheet** to your **Applications** folder.

*(Note: If you are using an Intel-based Mac, please check the [Releases](https://github.com/newfull5/PasteSheets/releases) page for the appropriate version.)*

## Usage

| Action | Shortcut |
| :--- | :--- |
| **Toggle App** | `Cmd` + `Shift` + `V` |
| **Navigate** | `↑` `↓` `←` `→` Arrow Keys |
| **Paste / Select** | `Enter` |
| **Edit Item** | `Cmd` + `E` |
| **Close** | `Esc` |

**Pro Tip:** Move your mouse cursor to the **right edge** of the screen to quickly peek at your clipboard!

## 🛠 Troubleshooting

### ⚠️ macOS "Damaged" Error
Since this app is not signed with an Apple Developer certificate, macOS may show a "damaged" error or block the app from opening. To fix this, run the following command in your terminal:

```bash
xattr -cr /Applications/PasteSheet.app
```

Then, try opening the app again from your Applications folder.

## License

This project is licensed under the Apache License, Version 2.0.
