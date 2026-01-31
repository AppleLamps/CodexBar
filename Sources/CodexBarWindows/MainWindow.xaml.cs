using System;
using System.ComponentModel;
using System.Windows;

namespace CodexBarWindows;

/// <summary>
/// Main window for CodexBar.
/// Minimizes to system tray instead of taskbar.
/// </summary>
public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
    }

    private void Window_StateChanged(object sender, EventArgs e)
    {
        if (WindowState == WindowState.Minimized)
        {
            // Minimize to tray instead of taskbar
            Hide();
        }
    }

    private void Window_Closing(object sender, CancelEventArgs e)
    {
        // Don't actually close, just hide to tray
        e.Cancel = true;
        Hide();
    }
}
