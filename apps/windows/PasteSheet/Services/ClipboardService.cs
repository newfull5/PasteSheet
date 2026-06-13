using System.Runtime.InteropServices;
using Clipboard = System.Windows.Clipboard;

namespace PasteSheet.Services;

/// Wraps the Win32 clipboard. Uses GetClipboardSequenceNumber as the
/// change counter — the Windows equivalent of NSPasteboard.changeCount.
public sealed class ClipboardService
{
    [DllImport("user32.dll")]
    private static extern uint GetClipboardSequenceNumber();

    public string? GetText()
    {
        try
        {
            return Clipboard.ContainsText() ? Clipboard.GetText() : null;
        }
        catch
        {
            return null;
        }
    }

    public void SetText(string text)
    {
        try
        {
            Clipboard.SetText(text);
        }
        catch
        {
            // Clipboard may be locked by another process; ignore transient failures.
        }
    }

    public bool HasChanged(uint lastChangeCount) =>
        GetClipboardSequenceNumber() != lastChangeCount;

    public uint CurrentChangeCount() => GetClipboardSequenceNumber();
}
