using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
using System.Windows.Input;
using System.Windows.Media;
using CodexBarWindows.Models;
using CodexBarWindows.Services;

namespace CodexBarWindows.ViewModels;

/// <summary>
/// Main view model for the CodexBar window.
/// </summary>
public class MainViewModel : INotifyPropertyChanged
{
    private readonly UsageService _usageService;
    private bool _isLoading;
    private string _statusMessage = "Ready";
    private DateTime? _lastUpdated;

    public event PropertyChangedEventHandler? PropertyChanged;

    public ObservableCollection<ProviderViewModel> Providers { get; } = new();

    public ICommand RefreshCommand { get; }
    public ICommand OpenSettingsCommand { get; }

    public bool IsLoading
    {
        get => _isLoading;
        set => SetProperty(ref _isLoading, value);
    }

    public string StatusMessage
    {
        get => _statusMessage;
        set => SetProperty(ref _statusMessage, value);
    }

    public string LastUpdatedDisplay =>
        _lastUpdated.HasValue
            ? $"Last updated: {_lastUpdated:HH:mm:ss}"
            : "Not yet updated";

    public string TooltipSummary
    {
        get
        {
            if (Providers.Count == 0)
                return "CodexBar - No providers configured";

            var summary = Providers
                .OrderByDescending(p => p.UsagePercentage)
                .Take(3)
                .Select(p => $"{p.Name}: {p.UsagePercentage:F0}%");

            return $"CodexBar\n{string.Join("\n", summary)}";
        }
    }

    public MainViewModel(UsageService usageService)
    {
        _usageService = usageService;

        RefreshCommand = new RelayCommand(async _ => await RefreshAsync());
        OpenSettingsCommand = new RelayCommand(_ => OpenSettings());

        // Subscribe to usage updates
        _usageService.UsageUpdated += OnUsageUpdated;
        _usageService.ErrorOccurred += OnError;
    }

    public async Task RefreshAsync()
    {
        if (IsLoading) return;

        try
        {
            IsLoading = true;
            StatusMessage = "Fetching usage data...";

            await _usageService.FetchUsageAsync();
        }
        finally
        {
            IsLoading = false;
        }
    }

    private void OnUsageUpdated(object? sender, UsageDataEventArgs e)
    {
        // Update on UI thread
        System.Windows.Application.Current?.Dispatcher.Invoke(() =>
        {
            Providers.Clear();

            foreach (var usage in e.Providers.OrderByDescending(p => p.UsagePercentage))
            {
                Providers.Add(new ProviderViewModel(usage));
            }

            _lastUpdated = DateTime.Now;
            StatusMessage = $"Updated {Providers.Count} providers";

            OnPropertyChanged(nameof(LastUpdatedDisplay));
            OnPropertyChanged(nameof(TooltipSummary));
        });
    }

    private void OnError(object? sender, ErrorEventArgs e)
    {
        System.Windows.Application.Current?.Dispatcher.Invoke(() =>
        {
            StatusMessage = $"Error: {e.Exception.Message}";
            IsLoading = false;
        });
    }

    private void OpenSettings()
    {
        var settingsWindow = new SettingsWindow();
        settingsWindow.ShowDialog();
    }

    protected virtual void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }

    protected bool SetProperty<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (Equals(field, value)) return false;
        field = value;
        OnPropertyChanged(propertyName);
        return true;
    }
}

/// <summary>
/// View model for a single provider.
/// </summary>
public class ProviderViewModel : INotifyPropertyChanged
{
    private readonly ProviderUsage _usage;

    public event PropertyChangedEventHandler? PropertyChanged;

    public ProviderViewModel(ProviderUsage usage)
    {
        _usage = usage;
    }

    public string Name => _usage.Name;
    public double UsagePercentage => _usage.UsagePercentage;
    public string UsedDisplay => _usage.UsedDisplay;
    public string RemainingDisplay => _usage.RemainingDisplay;
    public string ResetDateDisplay => _usage.ResetDateDisplay;
    public string Status => _usage.Status;

    public Brush AccentColor => GetAccentColor(_usage.Name);

    private static Brush GetAccentColor(string providerName)
    {
        return providerName.ToLowerInvariant() switch
        {
            "claude" or "anthropic" => new SolidColorBrush(Color.FromRgb(204, 119, 68)),  // Orange/brown
            "openai" or "codex" or "chatgpt" => new SolidColorBrush(Color.FromRgb(16, 163, 127)),  // Green
            "gemini" or "google" => new SolidColorBrush(Color.FromRgb(66, 133, 244)),  // Blue
            "copilot" or "github" => new SolidColorBrush(Color.FromRgb(36, 41, 46)),  // Dark gray
            "cursor" => new SolidColorBrush(Color.FromRgb(123, 97, 255)),  // Purple
            "jetbrains" => new SolidColorBrush(Color.FromRgb(255, 90, 50)),  // Red-orange
            _ => new SolidColorBrush(Color.FromRgb(128, 128, 128))  // Gray
        };
    }
}

/// <summary>
/// Simple relay command implementation.
/// </summary>
public class RelayCommand : ICommand
{
    private readonly Action<object?> _execute;
    private readonly Func<object?, bool>? _canExecute;

    public event EventHandler? CanExecuteChanged
    {
        add => CommandManager.RequerySuggested += value;
        remove => CommandManager.RequerySuggested -= value;
    }

    public RelayCommand(Action<object?> execute, Func<object?, bool>? canExecute = null)
    {
        _execute = execute ?? throw new ArgumentNullException(nameof(execute));
        _canExecute = canExecute;
    }

    public bool CanExecute(object? parameter) => _canExecute?.Invoke(parameter) ?? true;

    public void Execute(object? parameter) => _execute(parameter);
}
