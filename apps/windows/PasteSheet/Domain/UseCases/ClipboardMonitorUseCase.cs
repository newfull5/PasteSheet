using System.Windows.Threading;
using PasteSheet.App;
using PasteSheet.Domain.Repositories;
using PasteSheet.Services;

namespace PasteSheet.Domain.UseCases;

public sealed class ClipboardMonitorUseCase
{
    private readonly IPasteItemRepository _itemRepo;
    private readonly ClipboardService _clipboardService;
    private DispatcherTimer? _timer;
    private uint _lastChangeCount;

    public ClipboardMonitorUseCase(IPasteItemRepository itemRepo, ClipboardService clipboardService)
    {
        _itemRepo = itemRepo;
        _clipboardService = clipboardService;
    }

    public void StartMonitoring(Action onChange)
    {
        _lastChangeCount = _clipboardService.CurrentChangeCount();
        _timer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(Constants.ClipboardPollingIntervalMs)
        };
        _timer.Tick += (_, _) => Poll(onChange);
        _timer.Start();
    }

    public void StopMonitoring()
    {
        _timer?.Stop();
        _timer = null;
    }

    private void Poll(Action onChange)
    {
        if (!_clipboardService.HasChanged(_lastChangeCount)) return;
        _lastChangeCount = _clipboardService.CurrentChangeCount();

        var text = _clipboardService.GetText();
        if (string.IsNullOrWhiteSpace(text)) return;

        try
        {
            var existing = _itemRepo.FindByContent(text, Constants.DefaultDirectory);
            if (existing is not null)
            {
                _itemRepo.UpdateItem(existing.Id, text, Constants.DefaultDirectory, existing.Memo);
            }
            else
            {
                _itemRepo.CreateItem(text, Constants.DefaultDirectory, null);
                _itemRepo.CleanupOldItems(Constants.DefaultDirectory, Constants.MaxItemsPerDirectory);
            }
            onChange();
        }
        catch (Exception ex)
        {
            System.Diagnostics.Debug.WriteLine($"ClipboardMonitor error: {ex}");
        }
    }
}
