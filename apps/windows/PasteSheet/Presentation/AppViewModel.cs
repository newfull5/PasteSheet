using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Windows.Input;
using System.Windows.Threading;
using PasteSheet.App;
using PasteSheet.Domain.Entities;
using PasteSheet.Domain.UseCases;
using PasteSheet.Services;

namespace PasteSheet.Presentation;

public enum ViewType { Directories, Items, Settings }

public sealed class AppViewModel : INotifyPropertyChanged
{
    // MARK: - Dependencies
    private readonly ManageItemsUseCase _manageItems;
    private readonly ManageDirectoriesUseCase _manageDirectories;
    private readonly SearchUseCase _searchUseCase;
    private readonly PasteTextUseCase _pasteText;
    public ClipboardMonitorUseCase ClipboardMonitor { get; }
    private readonly SettingsUseCase _settingsUseCase;
    private readonly ForegroundWindowService _foregroundWindowService;

    public IWindowHost? Host { get; set; }

    public AppViewModel(
        ManageItemsUseCase manageItems,
        ManageDirectoriesUseCase manageDirectories,
        SearchUseCase searchUseCase,
        PasteTextUseCase pasteText,
        ClipboardMonitorUseCase clipboardMonitor,
        SettingsUseCase settingsUseCase,
        ForegroundWindowService foregroundWindowService)
    {
        _manageItems = manageItems;
        _manageDirectories = manageDirectories;
        _searchUseCase = searchUseCase;
        _pasteText = pasteText;
        ClipboardMonitor = clipboardMonitor;
        _settingsUseCase = settingsUseCase;
        _foregroundWindowService = foregroundWindowService;
    }

    // MARK: - State
    private ViewType _currentView = ViewType.Directories;
    public ViewType CurrentView { get => _currentView; set { _currentView = value; OnChanged(); RebuildRows(); } }

    private string _searchQuery = "";
    public string SearchQuery
    {
        get => _searchQuery;
        set { _searchQuery = value; OnChanged(); RebuildRows(); }
    }

    private int _selectedIndex;
    public int SelectedIndex { get => _selectedIndex; set { _selectedIndex = value; OnChanged(); SyncSelection(); } }

    public string CurrentDirectory { get; private set; } = "";

    private int _buttonFocusIndex;
    public int ButtonFocusIndex
    {
        get => _buttonFocusIndex;
        private set { _buttonFocusIndex = value; OnChanged(); }
    }

    private List<DirectoryInfo> _directories = new();
    private List<PasteItem> _allItems = new();

    public ObservableCollection<RowItem> Rows { get; } = new();

    private ModalState? _modal;
    public ModalState? Modal { get => _modal; set { _modal = value; OnChanged(); OnChanged(nameof(HasModal)); } }
    public bool HasModal => _modal is not null;

    private PasteItem? _detailItem;
    public PasteItem? DetailItem { get => _detailItem; set { _detailItem = value; OnChanged(); OnChanged(nameof(HasDetail)); } }
    public bool HasDetail => _detailItem is not null;

    private long? _editingItemId;
    public long? EditingItemId { get => _editingItemId; private set { _editingItemId = value; OnChanged(); OnChanged(nameof(IsEditing)); } }
    public bool IsEditing => _editingItemId is not null;
    public string EditContent { get; set; } = "";
    public string EditMemo { get; set; } = "";

    public bool IsAutoHideMode { get; private set; }

    // Auto-hide
    private bool _autoHideEnabled;
    private int _autoHideTimeout = Constants.DefaultAutoHideTimeout;
    private DispatcherTimer? _autoHideTimer;

    // MARK: - Computed

    public List<DirectoryInfo> FilteredDirectories =>
        string.IsNullOrEmpty(SearchQuery)
            ? _directories
            : _searchUseCase.Search(SearchQuery, _allItems, _directories).Directories;

    public List<PasteItem> FilteredItems
    {
        get
        {
            if (!string.IsNullOrEmpty(SearchQuery))
                return _searchUseCase.Search(SearchQuery, _allItems, _directories).Items;
            return _allItems.Where(i => i.Directory == CurrentDirectory).ToList();
        }
    }

    public int ListCount
    {
        get
        {
            if (!string.IsNullOrEmpty(SearchQuery))
                return FilteredDirectories.Count + FilteredItems.Count;
            if (CurrentView == ViewType.Directories)
                return FilteredDirectories.Count + 1;
            return FilteredItems.Count + 1;
        }
    }

    // MARK: - Row building

    public string HeaderTitle
    {
        get
        {
            if (!string.IsNullOrEmpty(SearchQuery)) return "Search results";
            return CurrentView switch
            {
                ViewType.Settings => "Settings",
                ViewType.Items => CurrentDirectory,
                _ => "PasteSheet"
            };
        }
    }

    public bool ShowBack =>
        (CurrentView is ViewType.Items or ViewType.Settings) && string.IsNullOrEmpty(SearchQuery);

    private void RebuildRows()
    {
        Rows.Clear();
        if (CurrentView == ViewType.Settings) { OnChanged(nameof(HeaderTitle)); OnChanged(nameof(ShowBack)); return; }

        if (!string.IsNullOrEmpty(SearchQuery))
        {
            foreach (var d in FilteredDirectories)
                Rows.Add(new RowItem { Kind = RowKind.Directory, Directory = d });
            foreach (var it in FilteredItems)
                Rows.Add(new RowItem { Kind = RowKind.Item, Item = it });
        }
        else if (CurrentView == ViewType.Directories)
        {
            foreach (var d in FilteredDirectories)
                Rows.Add(new RowItem { Kind = RowKind.Directory, Directory = d });
            Rows.Add(new RowItem { Kind = RowKind.NewFolder });
        }
        else
        {
            foreach (var it in FilteredItems)
                Rows.Add(new RowItem { Kind = RowKind.Item, Item = it });
            Rows.Add(new RowItem { Kind = RowKind.NewItem });
        }
        OnChanged(nameof(HeaderTitle));
        OnChanged(nameof(ShowBack));
        SyncSelection();
    }

    private void SyncSelection()
    {
        if (Rows.Count == 0) return;
        if (_selectedIndex < 0) _selectedIndex = 0;
        if (_selectedIndex >= Rows.Count) _selectedIndex = Rows.Count - 1;
        OnChanged(nameof(SelectedIndex));
    }

    // MARK: - View Navigation

    public void ShowDirectoryView()
    {
        var lastDir = CurrentDirectory;
        _currentView = ViewType.Directories;
        _searchQuery = "";
        LoadDirectories();
        var idx = _directories.FindIndex(d => d.Name == lastDir);
        _selectedIndex = idx >= 0 ? idx : 0;
        OnChanged(nameof(CurrentView));
        OnChanged(nameof(SearchQuery));
        RebuildRows();
    }

    public void ShowItemView(string directoryName)
    {
        CurrentDirectory = directoryName;
        _currentView = ViewType.Items;
        _searchQuery = "";
        _selectedIndex = 0;
        ButtonFocusIndex = 0;
        LoadHistory();
        OnChanged(nameof(CurrentView));
        OnChanged(nameof(SearchQuery));
        RebuildRows();
    }

    public void ShowSettingsView()
    {
        _searchQuery = "";
        CurrentView = ViewType.Settings;
        OnChanged(nameof(SearchQuery));
    }

    // MARK: - Data Loading

    public void LoadDirectories()
    {
        try { _directories = _manageDirectories.GetAllDirectories(); }
        catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"Load dirs: {ex}"); }
    }

    public void LoadHistory()
    {
        try { _allItems = _manageItems.GetAllItems(); }
        catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"Load history: {ex}"); }
    }

    public void OnWindowBecameVisible()
    {
        LoadDirectories();
        LoadHistory();
        LoadAutoHideSettings();
        ResetAutoHideTimer();
        _searchQuery = "";
        OnChanged(nameof(SearchQuery));
        if (CurrentView == ViewType.Directories) _selectedIndex = 0;
        RebuildRows();
    }

    public void OnClipboardUpdated()
    {
        LoadDirectories();
        LoadHistory();
        RebuildRows();
    }

    // MARK: - Item Actions

    public async void PasteItem(PasteItem item)
    {
        // Order matters: hand focus back to the target while we still own the
        // foreground (allowed), THEN hide, THEN paste. Hiding first would drop
        // our foreground and the OS would block the focus handover.
        _pasteText.PrepareAndRestoreFocus(item.Content);
        Host?.HidePanelImmediate();
        // Adaptive: waits only until the target regains foreground, then pastes.
        await _pasteText.SendPasteWhenReadyAsync();
    }

    public void StartEdit(PasteItem item)
    {
        EditContent = item.Content;
        EditMemo = item.Memo ?? "";
        CurrentDirectory = item.Directory;
        EditingItemId = item.Id;
        OnChanged(nameof(EditContent));
        OnChanged(nameof(EditMemo));
    }

    public void SaveEdit()
    {
        if (EditingItemId is not long id) return;
        try
        {
            _manageItems.UpdateItem(id, EditContent, CurrentDirectory, string.IsNullOrEmpty(EditMemo) ? null : EditMemo);
            EditingItemId = null;
            LoadHistory();
            LoadDirectories();
            RebuildRows();
        }
        catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"Save edit: {ex}"); }
    }

    public void CancelEdit() => EditingItemId = null;

    public void CreateItem(string content, string? memo)
    {
        try
        {
            _manageItems.CreateItem(content, CurrentDirectory, memo);
            LoadHistory();
            LoadDirectories();
            RebuildRows();
        }
        catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"Create item: {ex}"); }
    }

    public void DeleteItem(long id)
    {
        Modal = new ModalState
        {
            Title = "Delete Item",
            Message = "Are you sure you want to delete this item?",
            ConfirmText = "Delete",
            IsDanger = true,
            OnConfirm = _ =>
            {
                try
                {
                    _manageItems.DeleteItem(id);
                    LoadHistory(); LoadDirectories(); RebuildRows();
                }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"Delete item: {ex}"); }
            }
        };
    }

    // MARK: - Directory Actions

    public void CreateDirectory(string name)
    {
        try { _manageDirectories.CreateDirectory(name); LoadDirectories(); RebuildRows(); }
        catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"Create dir: {ex}"); }
    }

    public void RenameDirectory(string oldName)
    {
        Modal = new ModalState
        {
            Title = "Rename Folder",
            Message = "Enter new name for the folder:",
            ConfirmText = "Rename",
            ShowInput = true,
            InputValue = oldName,
            OnConfirm = newName =>
            {
                if (string.IsNullOrEmpty(newName) || newName == oldName) return;
                try { _manageDirectories.RenameDirectory(oldName, newName); LoadDirectories(); RebuildRows(); }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"Rename dir: {ex}"); }
            }
        };
    }

    public void DeleteDirectory(string name)
    {
        Modal = new ModalState
        {
            Title = "Delete Folder",
            Message = $"Are you sure you want to delete folder \"{name}\"? All items inside will be lost.",
            ConfirmText = "Delete",
            IsDanger = true,
            OnConfirm = _ =>
            {
                try { _manageDirectories.DeleteDirectory(name); LoadDirectories(); RebuildRows(); }
                catch (Exception ex) { System.Diagnostics.Debug.WriteLine($"Delete dir: {ex}"); }
            }
        };
    }

    public void PromptNewFolder()
    {
        Modal = new ModalState
        {
            Title = "New Folder",
            Message = "Enter a name for the new folder:",
            ConfirmText = "Create",
            ShowInput = true,
            OnConfirm = name => { if (!string.IsNullOrWhiteSpace(name)) CreateDirectory(name.Trim()); }
        };
    }

    public void PromptNewItem()
    {
        Modal = new ModalState
        {
            Title = "New Item",
            Message = "Enter the content:",
            ConfirmText = "Create",
            ShowInput = true,
            OnConfirm = content => { if (!string.IsNullOrWhiteSpace(content)) CreateItem(content, null); }
        };
    }

    public void ConfirmModal()
    {
        var m = Modal;
        Modal = null;
        m?.OnConfirm(m.ShowInput ? m.InputValue : null);
    }

    public void CancelModal() => Modal = null;

    // MARK: - Settings

    public bool MouseEdgeEnabled
    {
        get => _settingsUseCase.GetSetting("mouse_edge_enabled") != "false";
        set { _settingsUseCase.SetSetting("mouse_edge_enabled", value ? "true" : "false"); OnChanged(); }
    }

    public bool AutoStartEnabled
    {
        get => _settingsUseCase.IsAutoStartEnabled();
        set { _settingsUseCase.SetAutoStart(value); OnChanged(); }
    }

    public bool AutoHideEnabled
    {
        get => _settingsUseCase.GetSetting("auto_hide_enabled") == "true";
        set
        {
            _settingsUseCase.SetSetting("auto_hide_enabled", value ? "true" : "false");
            _autoHideEnabled = value;
            OnChanged();
            if (value) ResetAutoHideTimer(); else ClearAutoHideTimer();
        }
    }

    public int AutoHideTimeout
    {
        get
        {
            return int.TryParse(_settingsUseCase.GetSetting("auto_hide_timeout"), out var t)
                ? t : Constants.DefaultAutoHideTimeout;
        }
        set
        {
            _settingsUseCase.SetSetting("auto_hide_timeout", value.ToString());
            _autoHideTimeout = value;
            OnChanged();
            if (_autoHideEnabled) ResetAutoHideTimer();
        }
    }

    public void SetAutoHideTimeout(int seconds) => AutoHideTimeout = seconds;

    public bool AutoUpdateEnabled
    {
        get => _settingsUseCase.GetSetting("auto_update_enabled") != "false";
        set { _settingsUseCase.SetSetting("auto_update_enabled", value ? "true" : "false"); OnChanged(); }
    }

    /// Formatted toggle shortcut, e.g. "Ctrl Shift V" (Windows-style).
    public string ShortcutDisplay
    {
        get
        {
            var raw = _settingsUseCase.GetSetting("shortcut") ?? Constants.DefaultShortcut;
            var parts = raw.Split('+', StringSplitOptions.RemoveEmptyEntries)
                .Select(p => p switch
                {
                    "CommandOrControl" or "Command" or "Ctrl" or "Control" => "Ctrl",
                    "Option" => "Alt",
                    "Super" => "Win",
                    _ => p
                });
            return string.Join(" ", parts);
        }
    }

    public string AppVersion => _updateService.CurrentVersion;
    public string DeveloperName => "newfull5";

    private readonly UpdateService _updateService = new();

    public async void CheckForUpdates()
    {
        var result = await _updateService.CheckAsync();
        if (result is not { } r)
        {
            Modal = new ModalState
            {
                Title = "Check for Updates",
                Message = "Could not reach the update server. Please try again later.",
                ConfirmText = "OK",
                CancelText = "Close",
                OnConfirm = _ => { }
            };
            return;
        }

        if (r.HasUpdate)
        {
            Modal = new ModalState
            {
                Title = "Update Available",
                Message = $"Version {r.LatestVersion} is available (you have {_updateService.CurrentVersion}). Open the download page?",
                ConfirmText = "Download",
                OnConfirm = _ => _updateService.OpenReleasesPage()
            };
        }
        else
        {
            Modal = new ModalState
            {
                Title = "You're up to date",
                Message = $"PasteSheet {_updateService.CurrentVersion} is the latest version.",
                ConfirmText = "OK",
                CancelText = "Close",
                OnConfirm = _ => { }
            };
        }
    }

    /// Silent background check used at startup; returns the result so the caller
    /// can surface an unobtrusive notification (e.g. a tray balloon).
    public async Task<UpdateService.UpdateCheckResult?> CheckUpdateSilentAsync()
    {
        if (!AutoUpdateEnabled) return null;
        return await _updateService.CheckAsync();
    }

    public void OpenReleasesPage() => _updateService.OpenReleasesPage();

    // MARK: - Window

    public void ToggleWindow()
    {
        if (Host is null) return;
        if (Host.IsVisible)
        {
            IsAutoHideMode = false;
            ClearAutoHideTimer();
            Host.HidePanel();
        }
        else
        {
            Host.ShowPanel();
            OnWindowBecameVisible();
        }
    }

    public void ShowWindowFromEdge()
    {
        if (Host is null || Host.IsVisible) return;
        IsAutoHideMode = true;
        Host.ShowPanel();
        OnWindowBecameVisible();
    }

    public void OnPanelHidden()
    {
        IsAutoHideMode = false;
        ClearAutoHideTimer();
    }

    public void HideWindowFromEdge()
    {
        if (Host is null || !Host.IsVisible || !IsAutoHideMode) return;
        IsAutoHideMode = false;
        ClearAutoHideTimer();
        Host.HidePanel();
    }

    public void SaveForegroundBeforeShow(IntPtr ownHandle) =>
        _foregroundWindowService.SaveCurrentWindow(ownHandle);

    // MARK: - Auto-hide timer

    public void ResetAutoHideTimer()
    {
        if (!_autoHideEnabled || Host is null || !Host.IsVisible) return;
        ClearAutoHideTimer();
        _autoHideTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(_autoHideTimeout) };
        _autoHideTimer.Tick += (_, _) => ToggleWindow();
        _autoHideTimer.Start();
    }

    private void ClearAutoHideTimer()
    {
        _autoHideTimer?.Stop();
        _autoHideTimer = null;
    }

    private void LoadAutoHideSettings()
    {
        _autoHideEnabled = _settingsUseCase.GetSetting("auto_hide_enabled") == "true";
        if (int.TryParse(_settingsUseCase.GetSetting("auto_hide_timeout"), out var t))
            _autoHideTimeout = t;
    }

    // MARK: - Keyboard

    /// Returns true if the key was consumed. Mirrors macOS handleKeyDown.
    public bool HandleKey(Key key, ModifierKeys mods, bool isInput)
    {
        ResetAutoHideTimer();
        bool hasCmd = mods.HasFlag(ModifierKeys.Control);

        // Escape chain
        if (key == Key.Escape)
        {
            if (Modal is not null) { Modal = null; return true; }
            if (DetailItem is not null) { DetailItem = null; return true; }
            if (EditingItemId is not null) { EditingItemId = null; return true; }
            if (CurrentView == ViewType.Settings) { ShowDirectoryView(); return true; }
            if (!string.IsNullOrEmpty(SearchQuery)) { SearchQuery = ""; return true; }
            ToggleWindow();
            return true;
        }

        if (Modal is not null)
        {
            if (key == Key.Return) { ConfirmModal(); return true; }
            return false;
        }
        if (DetailItem is not null) return false;

        // Ctrl+Enter saves edit
        if (EditingItemId is not null && isInput && key == Key.Return && hasCmd) { SaveEdit(); return true; }
        // Ctrl+E starts edit
        if (key == Key.E && hasCmd && CurrentView == ViewType.Items)
        {
            var its = FilteredItems;
            if (SelectedIndex < its.Count) { StartEdit(its[SelectedIndex]); return true; }
        }

        switch (key)
        {
            case Key.Down:
                SelectedIndex = (SelectedIndex + 1) % Math.Max(ListCount, 1);
                ButtonFocusIndex = 0;
                return true;
            case Key.Up:
                SelectedIndex = (SelectedIndex - 1 + Math.Max(ListCount, 1)) % Math.Max(ListCount, 1);
                ButtonFocusIndex = 0;
                return true;
            case Key.Right:
                if (!string.IsNullOrEmpty(SearchQuery)) return false;
                if (CurrentView == ViewType.Directories)
                {
                    var dirs = FilteredDirectories;
                    if (SelectedIndex < dirs.Count) { ShowItemView(dirs[SelectedIndex].Name); return true; }
                }
                else if (CurrentView == ViewType.Items && ButtonFocusIndex < 2)
                {
                    ButtonFocusIndex++; OnChanged(nameof(ButtonFocusIndex)); return true;
                }
                break;
            case Key.Left:
                if (!string.IsNullOrEmpty(SearchQuery)) return false;
                if (CurrentView == ViewType.Items)
                {
                    if (ButtonFocusIndex > 0) { ButtonFocusIndex--; OnChanged(nameof(ButtonFocusIndex)); return true; }
                    ShowDirectoryView(); return true;
                }
                if (CurrentView == ViewType.Settings) { ShowDirectoryView(); return true; }
                break;
        }

        // Enter
        if (key == Key.Return && (EditingItemId is null || !isInput))
        {
            if (!string.IsNullOrEmpty(SearchQuery)) { ExecuteSearchAction(); return true; }
            if (CurrentView == ViewType.Directories)
            {
                var dirs = FilteredDirectories;
                if (SelectedIndex < dirs.Count) ShowItemView(dirs[SelectedIndex].Name);
                else PromptNewFolder();
                return true;
            }
            if (CurrentView == ViewType.Items) { ExecuteItemAction(); return true; }
        }

        // Space - detail view
        if (key == Key.Space && !isInput && CurrentView == ViewType.Items && string.IsNullOrEmpty(SearchQuery))
        {
            var its = FilteredItems;
            if (SelectedIndex < its.Count) { DetailItem = its[SelectedIndex]; return true; }
        }

        // Ctrl+Backspace delete
        if (key == Key.Back && hasCmd && !isInput)
        {
            var dirs = FilteredDirectories;
            if (!string.IsNullOrEmpty(SearchQuery))
            {
                if (SelectedIndex < dirs.Count) DeleteDirectory(dirs[SelectedIndex].Name);
                else { var idx = SelectedIndex - dirs.Count; var its = FilteredItems; if (idx < its.Count) DeleteItem(its[idx].Id); }
            }
            else if (CurrentView == ViewType.Directories)
            {
                if (SelectedIndex < dirs.Count) DeleteDirectory(dirs[SelectedIndex].Name);
            }
            else if (CurrentView == ViewType.Items)
            {
                var its = FilteredItems;
                if (SelectedIndex < its.Count) DeleteItem(its[SelectedIndex].Id);
            }
            return true;
        }

        return false;
    }

    private void ExecuteSearchAction()
    {
        var dirs = FilteredDirectories;
        if (SelectedIndex < dirs.Count) ShowItemView(dirs[SelectedIndex].Name);
        else
        {
            var idx = SelectedIndex - dirs.Count;
            var its = FilteredItems;
            if (idx < its.Count) ExecuteActionOnItem(its[idx]);
        }
    }

    private void ExecuteItemAction()
    {
        var its = FilteredItems;
        if (SelectedIndex < its.Count) ExecuteActionOnItem(its[SelectedIndex]);
        else PromptNewItem();
    }

    private void ExecuteActionOnItem(PasteItem item)
    {
        switch (ButtonFocusIndex)
        {
            case 0: PasteItem(item); break;
            case 1: StartEdit(item); break;
            case 2: DeleteItem(item.Id); break;
        }
    }

    // MARK: - INotifyPropertyChanged

    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnChanged([CallerMemberName] string? name = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
