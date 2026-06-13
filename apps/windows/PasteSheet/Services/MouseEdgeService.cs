using System.Windows.Threading;
using PasteSheet.App;

namespace PasteSheet.Services;

/// Polls the cursor; when it reaches the right screen edge the window peeks out,
/// and hides again when the cursor leaves. Mirrors the macOS MouseEdgeService.
public sealed class MouseEdgeService
{
    private DispatcherTimer? _timer;
    private bool _isEnabled = true;
    private readonly WindowPositionService _positionService = new();

    public void StartMonitoring(
        double windowWidthPhysical,
        Func<bool> isWindowVisible,
        Action onEdgeReached,
        Action onEdgeLeft)
    {
        _timer = new DispatcherTimer
        {
            Interval = TimeSpan.FromMilliseconds(Constants.MouseEdgePollingIntervalMs)
        };
        _timer.Tick += (_, _) =>
        {
            if (!_isEnabled) return;

            int cursorX = _positionService.CursorX();
            int rightEdge = _positionService.RightEdgeX();
            bool atRightEdge = cursorX >= rightEdge - Constants.MouseEdgeThreshold;
            bool outsideWindow = cursorX < rightEdge - windowWidthPhysical;
            bool visible = isWindowVisible();

            if (atRightEdge && !visible) onEdgeReached();
            else if (outsideWindow && visible) onEdgeLeft();
        };
        _timer.Start();
    }

    public void StopMonitoring()
    {
        _timer?.Stop();
        _timer = null;
    }

    public void SetEnabled(bool enabled) => _isEnabled = enabled;
}
