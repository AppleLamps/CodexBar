using System;
using System.Drawing;
using System.Windows;
using System.Windows.Controls;
using CodexBarWindows.ViewModels;
using Hardcodet.Wpf.TaskbarNotification;

namespace CodexBarWindows;

/// <summary>
/// Manages the system tray icon and context menu.
/// </summary>
public sealed class SystemTrayIcon : IDisposable
{
    private readonly TaskbarIcon _trayIcon;
    private readonly MainViewModel _viewModel;
    private bool _disposed;

    public SystemTrayIcon(MainViewModel viewModel)
    {
        _viewModel = viewModel;

        _trayIcon = new TaskbarIcon
        {
            ToolTipText = "CodexBar - API Usage Monitor",
            ContextMenu = CreateContextMenu(),
            DoubleClickCommand = new RelayCommand(_ => ShowMainWindow())
        };

        // Update tooltip with usage summary
        _viewModel.PropertyChanged += (s, e) =>
        {
            if (e.PropertyName == nameof(MainViewModel.TooltipSummary))
            {
                _trayIcon.ToolTipText = _viewModel.TooltipSummary;
            }
        };

        // Try to load icon from resources
        try
        {
            var iconUri = new Uri("pack://application:,,,/Resources/codexbar.ico", UriKind.Absolute);
            _trayIcon.IconSource = new System.Windows.Media.Imaging.BitmapImage(iconUri);
        }
        catch
        {
            // Fallback: Use a default system icon
        }
    }

    public void Show()
    {
        _trayIcon.Visibility = Visibility.Visible;
    }

    public void Hide()
    {
        _trayIcon.Visibility = Visibility.Collapsed;
    }

    public void ShowBalloonTip(string title, string message, BalloonIcon icon = BalloonIcon.Info)
    {
        _trayIcon.ShowBalloonTip(title, message, icon);
    }

    private ContextMenu CreateContextMenu()
    {
        var menu = new ContextMenu();

        // Show/Hide main window
        var showItem = new MenuItem { Header = "Show CodexBar" };
        showItem.Click += (s, e) => ShowMainWindow();
        menu.Items.Add(showItem);

        menu.Items.Add(new Separator());

        // Quick provider statuses (dynamically updated)
        var providersItem = new MenuItem { Header = "Providers" };
        providersItem.SubmenuOpened += (s, e) => UpdateProvidersSubmenu(providersItem);
        menu.Items.Add(providersItem);

        menu.Items.Add(new Separator());

        // Refresh
        var refreshItem = new MenuItem { Header = "Refresh Now" };
        refreshItem.Click += async (s, e) => await _viewModel.RefreshAsync();
        menu.Items.Add(refreshItem);

        // Settings
        var settingsItem = new MenuItem { Header = "Settings..." };
        settingsItem.Click += (s, e) => _viewModel.OpenSettingsCommand.Execute(null);
        menu.Items.Add(settingsItem);

        menu.Items.Add(new Separator());

        // Start with Windows
        var startupItem = new MenuItem
        {
            Header = "Start with Windows",
            IsCheckable = true,
            IsChecked = IsStartupEnabled()
        };
        startupItem.Click += (s, e) => ToggleStartup(startupItem.IsChecked);
        menu.Items.Add(startupItem);

        menu.Items.Add(new Separator());

        // Exit
        var exitItem = new MenuItem { Header = "Exit" };
        exitItem.Click += (s, e) => ExitApplication();
        menu.Items.Add(exitItem);

        return menu;
    }

    private void UpdateProvidersSubmenu(MenuItem providersItem)
    {
        providersItem.Items.Clear();

        foreach (var provider in _viewModel.Providers)
        {
            var item = new MenuItem
            {
                Header = $"{provider.Name}: {provider.UsagePercentage:F0}% used",
                IsEnabled = false
            };
            providersItem.Items.Add(item);
        }

        if (_viewModel.Providers.Count == 0)
        {
            var emptyItem = new MenuItem
            {
                Header = "No providers configured",
                IsEnabled = false
            };
            providersItem.Items.Add(emptyItem);
        }
    }

    private void ShowMainWindow()
    {
        if (Application.Current is App app)
        {
            app.ShowMainWindow();
        }
    }

    private void ExitApplication()
    {
        if (Application.Current is App app)
        {
            app.ExitApplication();
        }
    }

    private bool IsStartupEnabled()
    {
        try
        {
            using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", false);
            return key?.GetValue("CodexBar") != null;
        }
        catch
        {
            return false;
        }
    }

    private void ToggleStartup(bool enable)
    {
        try
        {
            using var key = Microsoft.Win32.Registry.CurrentUser.OpenSubKey(
                @"SOFTWARE\Microsoft\Windows\CurrentVersion\Run", true);

            if (key == null) return;

            if (enable)
            {
                var exePath = System.Diagnostics.Process.GetCurrentProcess().MainModule?.FileName;
                if (exePath != null)
                {
                    key.SetValue("CodexBar", $"\"{exePath}\" --minimized");
                }
            }
            else
            {
                key.DeleteValue("CodexBar", false);
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"Failed to update startup settings: {ex.Message}",
                "CodexBar",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
        }
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _trayIcon.Dispose();
    }
}
