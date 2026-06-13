using System.Runtime.InteropServices;
using System.Windows.Interop;

namespace PasteSheet.Services;

/// Global hotkey via Win32 RegisterHotKey. Creates a message-only window to
/// receive WM_HOTKEY. The Windows equivalent of the macOS Carbon hotkey.
public sealed class HotkeyService : IDisposable
{
    private const int WM_HOTKEY = 0x0312;
    private const int HOTKEY_ID = 1;

    private const uint MOD_ALT = 0x0001;
    private const uint MOD_CONTROL = 0x0002;
    private const uint MOD_SHIFT = 0x0004;
    private const uint MOD_WIN = 0x0008;
    private const uint MOD_NOREPEAT = 0x4000;

    [DllImport("user32.dll")]
    private static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);

    [DllImport("user32.dll")]
    private static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    private HwndSource? _source;
    private Action? _handler;
    private bool _registered;

    public void Register(string shortcut, Action handler)
    {
        _handler = handler;

        var parameters = new HwndSourceParameters("PasteSheetHotkey")
        {
            WindowClassStyle = 0,
            Width = 0,
            Height = 0,
            ParentWindow = new IntPtr(-3) // HWND_MESSAGE: message-only window
        };
        _source = new HwndSource(parameters);
        _source.AddHook(WndProc);

        var (modifiers, vk) = ParseShortcut(shortcut);
        _registered = RegisterHotKey(_source.Handle, HOTKEY_ID, modifiers | MOD_NOREPEAT, vk);
        if (!_registered)
            System.Diagnostics.Debug.WriteLine("[HotkeyService] Failed to register hotkey.");
    }

    public void UpdateShortcut(string shortcut, Action handler)
    {
        UnregisterAll();
        Register(shortcut, handler);
    }

    public void UnregisterAll()
    {
        if (_source is not null)
        {
            if (_registered) UnregisterHotKey(_source.Handle, HOTKEY_ID);
            _source.RemoveHook(WndProc);
            _source.Dispose();
            _source = null;
        }
        _registered = false;
    }

    private IntPtr WndProc(IntPtr hwnd, int msg, IntPtr wParam, IntPtr lParam, ref bool handled)
    {
        if (msg == WM_HOTKEY && wParam.ToInt32() == HOTKEY_ID)
        {
            _handler?.Invoke();
            handled = true;
        }
        return IntPtr.Zero;
    }

    private static (uint Modifiers, uint Vk) ParseShortcut(string shortcut)
    {
        uint modifiers = 0;
        uint vk = 0;

        foreach (var part in shortcut.Split('+', StringSplitOptions.RemoveEmptyEntries))
        {
            switch (part)
            {
                case "CommandOrControl":
                case "Command":
                case "Ctrl":
                case "Control":
                    modifiers |= MOD_CONTROL;
                    break;
                case "Shift":
                    modifiers |= MOD_SHIFT;
                    break;
                case "Alt":
                case "Option":
                    modifiers |= MOD_ALT;
                    break;
                case "Win":
                case "Super":
                    modifiers |= MOD_WIN;
                    break;
                default:
                    vk = VkForCharacter(part.ToUpperInvariant());
                    break;
            }
        }
        return (modifiers, vk);
    }

    private static uint VkForCharacter(string c)
    {
        if (c.Length == 1)
        {
            var ch = c[0];
            if (ch is >= 'A' and <= 'Z') return ch;          // VK_A..VK_Z == ASCII
            if (ch is >= '0' and <= '9') return ch;          // VK_0..VK_9 == ASCII
        }
        return (uint)'V';
    }

    public void Dispose() => UnregisterAll();
}
