using System;
using System.Windows;
using CodexBarWindows.Services;
using CodexBarWindows.ViewModels;

namespace CodexBarWindows;

/// <summary>
/// CodexBar Windows application entry point.
/// </summary>
public partial class App : Application
{
    private SystemTrayIcon? _trayIcon;
    private UsageService? _usageService;
    private MainViewModel? _mainViewModel;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Initialize services
        _usageService = new UsageService();
        _mainViewModel = new MainViewModel(_usageService);

        // Initialize system tray icon
        _trayIcon = new SystemTrayIcon(_mainViewModel);
        _trayIcon.Show();

        // Start periodic usage updates
        _usageService.StartPeriodicUpdates(TimeSpan.FromMinutes(5));

        // Handle command line arguments
        if (e.Args.Length > 0 && e.Args[0] == "--minimized")
        {
            // Start minimized to tray
            MainWindow?.Hide();
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _trayIcon?.Dispose();
        _usageService?.Dispose();
        base.OnExit(e);
    }

    public void ShowMainWindow()
    {
        if (MainWindow == null)
        {
            MainWindow = new MainWindow { DataContext = _mainViewModel };
        }

        MainWindow.Show();
        MainWindow.WindowState = WindowState.Normal;
        MainWindow.Activate();
    }

    public void ExitApplication()
    {
        _trayIcon?.Dispose();
        Shutdown();
    }
}
