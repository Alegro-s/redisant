using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace RozaCompanion.Services;

public sealed class RozaQuotaDto
{
    public string Plan { get; set; } = "free";
    public int TokensUsed { get; set; }
    public int TokensLimit { get; set; }
    public int TokensRemaining { get; set; }
    public bool ExternalApi { get; set; }
}

public static class RozaPlatformApi
{
    private static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true };

    public static async Task<RozaQuotaDto?> FetchQuotaAsync(string authApiUrl, string token, CancellationToken ct = default)
    {
        try
        {
            var baseUri = Normalize(authApiUrl);
            using var http = new HttpClient { BaseAddress = baseUri, Timeout = TimeSpan.FromSeconds(20) };
            using var req = new HttpRequestMessage(HttpMethod.Get, "me/roza/quota");
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.Trim());
            using var res = await http.SendAsync(req, ct).ConfigureAwait(false);
            if (!res.IsSuccessStatusCode)
                return null;
            var json = await res.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;
            return new RozaQuotaDto
            {
                Plan = root.TryGetProperty("plan", out var p) ? p.GetString() ?? "free" : "free",
                TokensUsed = root.TryGetProperty("tokens_used", out var u) ? u.GetInt32() : 0,
                TokensLimit = root.TryGetProperty("tokens_limit", out var l) ? l.GetInt32() : 8000,
                TokensRemaining = root.TryGetProperty("tokens_remaining", out var r) ? r.GetInt32() : 0,
                ExternalApi = root.TryGetProperty("external_api", out var e) && e.GetBoolean(),
            };
        }
        catch
        {
            return null;
        }
    }

    public static async Task SyncPrefsFromServerAsync(CompanionLocalPrefs prefs, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(prefs.AuthToken))
            return;
        var q = await FetchQuotaAsync(prefs.AuthApiUrl, prefs.AuthToken, ct).ConfigureAwait(false);
        if (q is null)
            return;
        prefs.SubscriptionPlan = string.Equals(q.Plan, "pro", StringComparison.OrdinalIgnoreCase)
            || string.Equals(q.Plan, "team", StringComparison.OrdinalIgnoreCase)
            || string.Equals(q.Plan, "enterprise", StringComparison.OrdinalIgnoreCase)
                ? "pro"
                : "free";
        prefs.TokensUsedToday = q.TokensUsed;
        prefs.TokensDayDate = DateTime.UtcNow.ToString("yyyy-MM-dd");
        CompanionLocalSettingsStore.Save(prefs);
    }

    private static Uri Normalize(string url)
    {
        var t = url.Trim();
        if (!t.StartsWith("http", StringComparison.OrdinalIgnoreCase))
            t = "http://" + t;
        return new Uri(t.TrimEnd('/') + "/");
    }
}
