using System;

namespace CodexBarWindows.Models;

/// <summary>
/// Represents usage data for an API provider.
/// </summary>
public class ProviderUsage
{
    public required string Name { get; init; }
    public double Used { get; init; }
    public double Limit { get; init; }
    public double Remaining { get; init; }
    public DateTime? ResetDate { get; init; }
    public string Status { get; init; } = "unknown";
    public string Unit { get; init; } = "requests";

    public double UsagePercentage =>
        Limit > 0 ? Math.Min(100, (Used / Limit) * 100) : 0;

    public string UsedDisplay =>
        FormatValue(Used, Unit);

    public string RemainingDisplay =>
        FormatValue(Remaining, Unit);

    public string LimitDisplay =>
        FormatValue(Limit, Unit);

    public string ResetDateDisplay =>
        ResetDate.HasValue
            ? $"Resets {FormatRelativeDate(ResetDate.Value)}"
            : "No reset date";

    private static string FormatValue(double value, string unit)
    {
        return unit.ToLowerInvariant() switch
        {
            "dollars" or "usd" => $"${value:F2}",
            "tokens" when value >= 1_000_000 => $"{value / 1_000_000:F1}M tokens",
            "tokens" when value >= 1_000 => $"{value / 1_000:F1}K tokens",
            "tokens" => $"{value:F0} tokens",
            "requests" when value >= 1_000 => $"{value / 1_000:F1}K requests",
            "requests" => $"{value:F0} requests",
            _ => $"{value:F0} {unit}"
        };
    }

    private static string FormatRelativeDate(DateTime date)
    {
        var diff = date - DateTime.Now;

        if (diff.TotalDays < 0)
            return "expired";
        if (diff.TotalDays < 1)
            return "today";
        if (diff.TotalDays < 2)
            return "tomorrow";
        if (diff.TotalDays < 7)
            return $"in {diff.Days} days";
        if (diff.TotalDays < 30)
            return $"in {diff.Days / 7} weeks";

        return date.ToString("MMM d");
    }
}
