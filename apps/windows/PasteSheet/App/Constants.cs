namespace PasteSheet.App;

public static class Constants
{
    public const double ClipboardPollingIntervalMs = 100;
    public const double MouseEdgePollingIntervalMs = 100;
    public const double MouseEdgeThreshold = 2.0;
    public const double WindowWidth = 380.0;
    public const double WindowMinHeight = 300.0;
    public const int PasteRestoreDelayMs1 = 80;
    public const int PasteRestoreDelayMs2 = 50;
    public const int PasteToggleDelayMs = 60;
    public const long MaxItemsPerDirectory = 30;
    public const string DefaultDirectory = "Clipboard";
    public const string DefaultShortcut = "Control+Shift+V";
    public const int DefaultAutoHideTimeout = 5;
}
