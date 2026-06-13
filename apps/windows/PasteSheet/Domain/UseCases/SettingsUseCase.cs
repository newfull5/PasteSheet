using PasteSheet.Domain.Repositories;
using PasteSheet.Services;

namespace PasteSheet.Domain.UseCases;

public sealed class SettingsUseCase
{
    private readonly ISettingsRepository _repo;
    private readonly MouseEdgeService _mouseEdgeService;
    private readonly AutoStartService _autoStartService;

    public SettingsUseCase(ISettingsRepository repo, MouseEdgeService mouseEdgeService, AutoStartService autoStartService)
    {
        _repo = repo;
        _mouseEdgeService = mouseEdgeService;
        _autoStartService = autoStartService;
    }

    public string? GetSetting(string key) => _repo.GetSetting(key);

    public void SetSetting(string key, string value)
    {
        _repo.SetSetting(key, value);
        if (key == "mouse_edge_enabled")
            _mouseEdgeService.SetEnabled(value == "true");
    }

    public void SetAutoStart(bool enabled)
    {
        if (enabled) _autoStartService.Enable();
        else _autoStartService.Disable();
        _repo.SetSetting("auto_start", enabled ? "true" : "false");
    }

    public bool IsAutoStartEnabled() => _autoStartService.IsEnabled();
}
