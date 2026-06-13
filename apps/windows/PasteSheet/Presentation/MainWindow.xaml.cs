using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;
using PasteSheet.App;
using PasteSheet.Services;
using KeyEventArgs = System.Windows.Input.KeyEventArgs;
using TextBox = System.Windows.Controls.TextBox;

namespace PasteSheet.Presentation;

public partial class MainWindow : Window, IWindowHost
{
    private readonly AppViewModel _vm;
    private readonly WindowPositionService _positionService = new();
    private readonly DispatcherTimer _cursorTimer = new() { Interval = TimeSpan.FromMilliseconds(500) };

    public double DpiScale { get; private set; } = 1.0;

    public MainWindow(AppViewModel vm)
    {
        _vm = vm;
        InitializeComponent();
        DataContext = vm;

        using (var g = System.Drawing.Graphics.FromHwnd(IntPtr.Zero))
            DpiScale = g.DpiX / 96.0;

        _vm.PropertyChanged += OnVmPropertyChanged;
        Deactivated += (_, _) => HideOnFocusLoss();
        PreviewKeyDown += OnPreviewKeyDown;
        SourceInitialized += (_, _) =>
        {
            DpiScale = VisualTreeHelper.GetDpi(this).DpiScaleX;
            ApplyNonTaskbarStyle();
        };

        _cursorTimer.Tick += (_, _) => CursorBlink.Opacity = CursorBlink.Opacity > 0 ? 0 : 1;
        _cursorTimer.Start();
    }

    // MARK: - IWindowHost

    bool IWindowHost.IsVisible => IsVisible;

    public void ShowPanel()
    {
        PositionWindow();
        Show();
        Activate();
        Dispatcher.BeginInvoke(() =>
        {
            SearchBox.Focus();
            SearchBox.SelectAll();
        }, DispatcherPriority.Input);
    }

    public void HidePanel() => Hide();

    public void FocusSearch() => SearchBox.Focus();

    public void SaveForegroundBeforeShow()
    {
        var handle = new WindowInteropHelper(this).Handle;
        _vm.SaveForegroundBeforeShow(handle);
    }

    // MARK: - Window placement / style

    private void PositionWindow()
    {
        var pos = _positionService.CalculatePosition(Constants.WindowWidth, DpiScale);
        Left = pos.X;
        Top = pos.Y;
        Width = pos.Width;
        Height = pos.Height;
    }

    private void ApplyNonTaskbarStyle()
    {
        // Tool window so it never appears in Alt-Tab.
        var helper = new WindowInteropHelper(this);
        const int GWL_EXSTYLE = -20;
        const int WS_EX_TOOLWINDOW = 0x00000080;
        var ex = NativeMethods.GetWindowLong(helper.Handle, GWL_EXSTYLE);
        NativeMethods.SetWindowLong(helper.Handle, GWL_EXSTYLE, ex | WS_EX_TOOLWINDOW);
    }

    private void HideOnFocusLoss()
    {
        if (!IsVisible) return;
        if (_vm.HasModal) return; // keep open while a modal is up
        _vm.OnPanelHidden();
        Hide();
    }

    // MARK: - Keyboard

    private void OnPreviewKeyDown(object sender, KeyEventArgs e)
    {
        bool isInput = Keyboard.FocusedElement is TextBox;
        var key = e.Key == Key.System ? e.SystemKey : e.Key;

        if (_vm.HandleKey(key, Keyboard.Modifiers, isInput))
        {
            e.Handled = true;
            List.ScrollIntoView(List.SelectedItem);
        }
    }

    private void OnVmPropertyChanged(object? sender, PropertyChangedEventArgs e)
    {
        switch (e.PropertyName)
        {
            case nameof(AppViewModel.HasModal) when _vm.HasModal && _vm.Modal!.ShowInput:
                Dispatcher.BeginInvoke(() => { ModalInput.Focus(); ModalInput.SelectAll(); }, DispatcherPriority.Input);
                break;
            case nameof(AppViewModel.IsEditing) when _vm.IsEditing:
                Dispatcher.BeginInvoke(() => { EditBox.Focus(); EditBox.CaretIndex = EditBox.Text.Length; }, DispatcherPriority.Input);
                break;
        }
    }

    // MARK: - Mouse / buttons

    private void OnListDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (List.SelectedItem is not RowItem row) return;
        switch (row.Kind)
        {
            case RowKind.Directory: _vm.ShowItemView(row.Directory!.Name); break;
            case RowKind.Item: _vm.PasteItem(row.Item!); break;
            case RowKind.NewFolder: _vm.PromptNewFolder(); break;
            case RowKind.NewItem: _vm.PromptNewItem(); break;
        }
    }

    private void OnSettingsClick(object sender, RoutedEventArgs e) => _vm.ShowSettingsView();
    private void OnBackClick(object sender, RoutedEventArgs e) => _vm.ShowDirectoryView();
    private void OnModalConfirm(object sender, RoutedEventArgs e) => _vm.ConfirmModal();
    private void OnModalCancel(object sender, RoutedEventArgs e) => _vm.CancelModal();

    private void OnRowPaste(object sender, RoutedEventArgs e)
    {
        if (RowItemFrom(sender) is { Item: { } item }) _vm.PasteItem(item);
    }

    private void OnRowEdit(object sender, RoutedEventArgs e)
    {
        if (RowItemFrom(sender) is { Item: { } item }) _vm.StartEdit(item);
    }

    private void OnRowDelete(object sender, RoutedEventArgs e)
    {
        if (RowItemFrom(sender) is { Item: { } item }) _vm.DeleteItem(item.Id);
    }

    private static RowItem? RowItemFrom(object sender) =>
        (sender as FrameworkElement)?.DataContext as RowItem;
}

internal static class NativeMethods
{
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [System.Runtime.InteropServices.DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
}
