using System.Runtime.InteropServices;

namespace PasteSheet.Services;

/// Saves and restores the previously-focused window so a paste lands in the
/// right app. The Windows equivalent of macOS PreviousAppService.
public sealed class ForegroundWindowService
{
    private IntPtr _previousWindow;

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    public void SaveCurrentWindow(IntPtr ownWindow)
    {
        var fg = GetForegroundWindow();
        if (fg != IntPtr.Zero && fg != ownWindow)
            _previousWindow = fg;
    }

    public void RestorePreviousWindow()
    {
        if (_previousWindow != IntPtr.Zero)
            SetForegroundWindow(_previousWindow);
    }
}
