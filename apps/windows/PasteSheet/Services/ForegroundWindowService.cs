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

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("user32.dll")]
    private static extern bool IsIconic(IntPtr hWnd);

    private const int SW_RESTORE = 9;

    public IntPtr PreviousWindow => _previousWindow;

    /// True once the saved target window actually owns the foreground again.
    public bool IsPreviousWindowForeground() =>
        _previousWindow != IntPtr.Zero && GetForegroundWindow() == _previousWindow;

    public void SaveCurrentWindow(IntPtr ownWindow)
    {
        var fg = GetForegroundWindow();
        if (fg != IntPtr.Zero && fg != ownWindow)
            _previousWindow = fg;
    }

    /// Hands focus back to the saved window. Must be called while OUR process is
    /// still the foreground window — a foreground process is always allowed to
    /// give focus away, so a plain SetForegroundWindow takes effect. (Attaching
    /// the input queues makes activation deterministic across processes.)
    public void RestorePreviousWindow()
    {
        var target = _previousWindow;
        if (target == IntPtr.Zero) return;

        if (IsIconic(target)) ShowWindow(target, SW_RESTORE);

        var fg = GetForegroundWindow();
        uint fgThread = fg != IntPtr.Zero ? GetWindowThreadProcessId(fg, out _) : GetCurrentThreadId();
        uint targetThread = GetWindowThreadProcessId(target, out _);
        bool attach = fgThread != 0 && targetThread != 0 && fgThread != targetThread;

        if (attach) AttachThreadInput(fgThread, targetThread, true);
        BringWindowToTop(target);
        SetForegroundWindow(target);
        if (attach) AttachThreadInput(fgThread, targetThread, false);
    }
}
