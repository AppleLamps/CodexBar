using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using CodexBarWindows.Models;

namespace CodexBarWindows.Services;

/// <summary>
/// Service for fetching API usage data from the CodexBar CLI.
/// </summary>
public sealed class UsageService : IDisposable
{
    private readonly string _cliPath;
    private Timer? _updateTimer;
    private bool _disposed;

    public event EventHandler<UsageDataEventArgs>? UsageUpdated;
    public event EventHandler<ErrorEventArgs>? ErrorOccurred;

    public UsageService()
    {
        _cliPath = FindCliPath();
    }

    /// <summary>
    /// Starts periodic usage updates.
    /// </summary>
    public void StartPeriodicUpdates(TimeSpan interval)
    {
        _updateTimer?.Dispose();
        _updateTimer = new Timer(
            async _ => await FetchUsageAsync(),
            null,
            TimeSpan.Zero,
            interval);
    }

    /// <summary>
    /// Stops periodic usage updates.
    /// </summary>
    public void StopPeriodicUpdates()
    {
        _updateTimer?.Dispose();
        _updateTimer = null;
    }

    /// <summary>
    /// Fetches current usage data for all providers.
    /// </summary>
    public async Task<List<ProviderUsage>> FetchUsageAsync()
    {
        var results = new List<ProviderUsage>();

        try
        {
            var output = await RunCliAsync("usage --json");
            if (string.IsNullOrEmpty(output))
            {
                return results;
            }

            var jsonDoc = JsonDocument.Parse(output);
            var root = jsonDoc.RootElement;

            if (root.TryGetProperty("providers", out var providers))
            {
                foreach (var provider in providers.EnumerateArray())
                {
                    var usage = ParseProviderUsage(provider);
                    if (usage != null)
                    {
                        results.Add(usage);
                    }
                }
            }

            UsageUpdated?.Invoke(this, new UsageDataEventArgs(results));
        }
        catch (Exception ex)
        {
            ErrorOccurred?.Invoke(this, new ErrorEventArgs(ex));
        }

        return results;
    }

    /// <summary>
    /// Fetches usage for a specific provider.
    /// </summary>
    public async Task<ProviderUsage?> FetchProviderUsageAsync(string providerName)
    {
        try
        {
            var output = await RunCliAsync($"usage --provider {providerName} --json");
            if (string.IsNullOrEmpty(output))
            {
                return null;
            }

            var jsonDoc = JsonDocument.Parse(output);
            return ParseProviderUsage(jsonDoc.RootElement);
        }
        catch (Exception ex)
        {
            ErrorOccurred?.Invoke(this, new ErrorEventArgs(ex));
            return null;
        }
    }

    private ProviderUsage? ParseProviderUsage(JsonElement element)
    {
        try
        {
            var name = element.GetProperty("name").GetString() ?? "Unknown";
            var used = element.TryGetProperty("used", out var usedProp) ? usedProp.GetDouble() : 0;
            var limit = element.TryGetProperty("limit", out var limitProp) ? limitProp.GetDouble() : 0;
            var remaining = element.TryGetProperty("remaining", out var remProp) ? remProp.GetDouble() : limit - used;

            DateTime? resetDate = null;
            if (element.TryGetProperty("resetDate", out var resetProp) &&
                DateTime.TryParse(resetProp.GetString(), out var parsed))
            {
                resetDate = parsed;
            }

            var status = element.TryGetProperty("status", out var statusProp)
                ? statusProp.GetString() ?? "unknown"
                : "unknown";

            var unit = element.TryGetProperty("unit", out var unitProp)
                ? unitProp.GetString() ?? "requests"
                : "requests";

            return new ProviderUsage
            {
                Name = name,
                Used = used,
                Limit = limit,
                Remaining = remaining,
                ResetDate = resetDate,
                Status = status,
                Unit = unit
            };
        }
        catch
        {
            return null;
        }
    }

    private async Task<string> RunCliAsync(string arguments)
    {
        if (string.IsNullOrEmpty(_cliPath))
        {
            throw new InvalidOperationException("CodexBar CLI not found");
        }

        using var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = _cliPath,
                Arguments = arguments,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true
            }
        };

        process.Start();

        var output = await process.StandardOutput.ReadToEndAsync();
        var error = await process.StandardError.ReadToEndAsync();

        await process.WaitForExitAsync();

        if (process.ExitCode != 0 && !string.IsNullOrEmpty(error))
        {
            throw new Exception($"CLI error: {error}");
        }

        return output;
    }

    private string FindCliPath()
    {
        // Check common locations
        var candidates = new[]
        {
            // Same directory as GUI
            System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "CodexBarCLI.exe"),
            // Program Files
            @"C:\Program Files\CodexBar\CodexBarCLI.exe",
            // User's local app data
            System.IO.Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "CodexBar", "CodexBarCLI.exe"),
            // PATH
            "CodexBarCLI.exe"
        };

        foreach (var path in candidates)
        {
            if (System.IO.File.Exists(path))
            {
                return path;
            }
        }

        // Try to find in PATH
        try
        {
            using var process = new Process
            {
                StartInfo = new ProcessStartInfo
                {
                    FileName = "where.exe",
                    Arguments = "CodexBarCLI.exe",
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true
                }
            };

            process.Start();
            var output = process.StandardOutput.ReadLine();
            process.WaitForExit();

            if (!string.IsNullOrEmpty(output) && System.IO.File.Exists(output))
            {
                return output;
            }
        }
        catch
        {
            // Ignore errors
        }

        return string.Empty;
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _updateTimer?.Dispose();
    }
}

public class UsageDataEventArgs : EventArgs
{
    public List<ProviderUsage> Providers { get; }

    public UsageDataEventArgs(List<ProviderUsage> providers)
    {
        Providers = providers;
    }
}

public class ErrorEventArgs : EventArgs
{
    public Exception Exception { get; }

    public ErrorEventArgs(Exception exception)
    {
        Exception = exception;
    }
}
