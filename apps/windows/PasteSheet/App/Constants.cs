namespace PasteSheet.App;

public static class Constants
{
    public const double ClipboardPollingIntervalMs = 100;
    public const double MouseEdgePollingIntervalMs = 100;
    public const double MouseEdgeThreshold = 2.0;
    public const double WindowWidth = 380.0;
    public const double WindowMinHeight = 300.0;
    public const double WindowMaxHeight = 1400.0;
    // Panel slide animation — source of truth: config/animation.json
    public const int SlideDurationMs = 190;
    public const double SlideOffsetPx = 48.0;
    // Tiny settle after the target regains foreground, before sending Ctrl+V.
    public const int PasteSettleDelayMs = 15;
    public const long MaxItemsPerDirectory = 30;
    public const string DefaultDirectory = "Clipboard";
    public const string DefaultShortcut = "Control+Shift+V";
    public const int DefaultAutoHideTimeout = 5;
}
