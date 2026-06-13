using PasteSheet.App;
using PasteSheet.Services;

namespace PasteSheet.Domain.UseCases;

public sealed class PasteTextUseCase
{
    private readonly ClipboardService _clipboardService;
    private readonly ForegroundWindowService _foregroundWindowService;
    private readonly KeySimulationService _keySimService;

    public PasteTextUseCase(ClipboardService clipboardService,
        ForegroundWindowService foregroundWindowService,
        KeySimulationService keySimService)
    {
        _clipboardService = clipboardService;
        _foregroundWindowService = foregroundWindowService;
        _keySimService = keySimService;
    }

    /// Step 1 — called while OUR window is still the foreground window: write the
    /// clipboard and hand focus back to the target. A foreground process is
    /// always allowed to give focus away, so no foreground-lock workaround is
    /// needed (unlike stealing focus from the background).
    public void PrepareAndRestoreFocus(string text)
    {
        _clipboardService.SetText(text);
        _foregroundWindowService.RestorePreviousWindow();
    }

    /// Step 2 — wait (adaptively, not a fixed sleep) until the target window
    /// actually owns the foreground, then fire Ctrl+V. Polls on short intervals
    /// up to a cap so it's fast on quick machines and tolerant on slow ones.
    public async Task SendPasteWhenReadyAsync()
    {
        const int pollMs = 8;
        const int maxWaitMs = 400;
        int waited = 0;
        while (waited < maxWaitMs && !_foregroundWindowService.IsPreviousWindowForeground())
        {
            await Task.Delay(pollMs);
            waited += pollMs;
        }
        // Small settle once focus has landed before injecting the keystroke.
        await Task.Delay(Constants.PasteSettleDelayMs);
        _keySimService.SimulatePaste();
    }
}
