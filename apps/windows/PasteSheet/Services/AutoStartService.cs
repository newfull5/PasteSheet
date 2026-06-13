using Microsoft.Win32;

namespace PasteSheet.Services;

/// Launch-at-login via the HKCU Run registry key. The Windows equivalent of
/// the macOS SMAppService.
public sealed class AutoStartService
{
    private const string RunKey = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "PasteSheet";

    // Environment.ProcessPath resolves to the real .exe path even for a
    // single-file published app (Assembly.Location would return "" there).
    private static string ExecutablePath =>
        Environment.ProcessPath ?? throw new InvalidOperationException("Cannot resolve executable path");

    public void Enable()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true)
                        ?? Registry.CurrentUser.CreateSubKey(RunKey);
        key.SetValue(ValueName, $"\"{ExecutablePath}\"");
    }

    public void Disable()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey, writable: true);
        key?.DeleteValue(ValueName, throwOnMissingValue: false);
    }

    public bool IsEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RunKey);
        return key?.GetValue(ValueName) is not null;
    }
}
