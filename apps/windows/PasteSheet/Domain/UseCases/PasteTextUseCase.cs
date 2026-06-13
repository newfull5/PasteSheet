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

    public void Execute(string text)
    {
        _clipboardService.SetText(text);

        _foregroundWindowService.RestorePreviousWindow();
        Thread.Sleep(Constants.PasteRestoreDelayMs1);

        _foregroundWindowService.RestorePreviousWindow();
        Thread.Sleep(Constants.PasteRestoreDelayMs2);

        _keySimService.SimulatePaste();
    }
}
