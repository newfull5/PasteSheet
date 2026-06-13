using System.Drawing;
using System.Windows;
using System.Windows.Forms;
using PasteSheet.Data.DataSources;
using PasteSheet.Data.Database;
using PasteSheet.Domain.Repositories;
using PasteSheet.Domain.UseCases;
using PasteSheet.Presentation;
using PasteSheet.Services;
using Application = System.Windows.Application;

namespace PasteSheet.App;

public partial class AppEntry : Application
{
    private MainWindow _window = null!;
    private NotifyIcon _trayIcon = null!;
    private AppViewModel _vm = null!;

    private readonly ClipboardService _clipboardService = new();
    private readonly ForegroundWindowService _foregroundWindowService = new();
    private readonly KeySimulationService _keySimService = new();
    private readonly HotkeyService _hotkeyService = new();
    private readonly MouseEdgeService _mouseEdgeService = new();
    private readonly AutoStartService _autoStartService = new();

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        try { DatabaseManager.Shared.Initialize(); }
        catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"DB init failed: {ex}"); Shutdown(); return; }

        var itemRepo = new PasteItemRepository(new PasteItemDataSource());
        var dirRepo = new DirectoryRepository(new DirectoryDataSource());
        var settingsRepo = new SettingsRepository(new SettingsDataSource());

        var settingsUseCase = new SettingsUseCase(settingsRepo, _mouseEdgeService, _autoStartService);

        // First-run: enable auto-start
        if (settingsUseCase.GetSetting("auto_start") is null)
            settingsUseCase.SetAutoStart(true);

        var edgeEnabled = settingsUseCase.GetSetting("mouse_edge_enabled") != "false";
        _mouseEdgeService.SetEnabled(edgeEnabled);

        _vm = new AppViewModel(
            new ManageItemsUseCase(itemRepo),
            new ManageDirectoriesUseCase(dirRepo),
            new SearchUseCase(),
            new PasteTextUseCase(_clipboardService, _foregroundWindowService, _keySimService),
            new ClipboardMonitorUseCase(itemRepo, _clipboardService),
            settingsUseCase,
            _foregroundWindowService);

        _window = new MainWindow(_vm);
        _vm.Host = _window;

        SetupTray();
        SetupHotkey(settingsUseCase);
        StartBackgroundServices();
        CheckUpdatesOnStartup();
    }

    private async void CheckUpdatesOnStartup()
    {
        var result = await _vm.CheckUpdateSilentAsync();
        if (result is { HasUpdate: true } r)
        {
            _trayIcon.BalloonTipTitle = "PasteSheet update available";
            _trayIcon.BalloonTipText = $"Version {r.LatestVersion} is available. Click to download.";
            _trayIcon.BalloonTipClicked -= OnUpdateBalloonClicked;
            _trayIcon.BalloonTipClicked += OnUpdateBalloonClicked;
            _trayIcon.ShowBalloonTip(8000);
        }
    }

    private void OnUpdateBalloonClicked(object? sender, EventArgs e) => _vm.OpenReleasesPage();

    private void SetupTray()
    {
        var iconStream = GetResourceStream(new Uri("pack://application:,,,/Assets/icon.ico"))?.Stream;
        _trayIcon = new NotifyIcon
        {
            Icon = iconStream != null ? new Icon(iconStream) : SystemIcons.Application,
            Visible = true,
            Text = "PasteSheet"
        };

        var menu = new ContextMenuStrip();
        menu.Items.Add("Show App", null, (_, _) => _vm.ToggleWindow());
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Quit PasteSheet", null, (_, _) => QuitApp());
        _trayIcon.ContextMenuStrip = menu;

        _trayIcon.MouseClick += (_, args) =>
        {
            if (args.Button == MouseButtons.Left)
            {
                _window.SaveForegroundBeforeShow();
                _vm.ToggleWindow();
            }
        };
    }

    private void SetupHotkey(SettingsUseCase settingsUseCase)
    {
        var shortcut = settingsUseCase.GetSetting("shortcut") ?? Constants.DefaultShortcut;
        _hotkeyService.Register(shortcut, () =>
        {
            _window.SaveForegroundBeforeShow();
            _vm.ToggleWindow();
        });
    }

    private void StartBackgroundServices()
    {
        _vm.ClipboardMonitor.StartMonitoring(() => _vm.OnClipboardUpdated());

        var widthPhysical = Constants.WindowWidth * _window.DpiScale;
        _mouseEdgeService.StartMonitoring(
            widthPhysical,
            () => _vm.Host?.IsVisible ?? false,
            () => _vm.ShowWindowFromEdge(),
            () => _vm.HideWindowFromEdge());
    }

    private void QuitApp()
    {
        _trayIcon.Visible = false;
        _trayIcon.Dispose();
        _hotkeyService.Dispose();
        Shutdown();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _trayIcon?.Dispose();
        _hotkeyService?.Dispose();
        base.OnExit(e);
    }
}
