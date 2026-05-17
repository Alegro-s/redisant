using System;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace RozaCompanion.Services;

public static class RozaAuthApi
{
    private static readonly JsonSerializerOptions Json = new() { PropertyNameCaseInsensitive = true };

    public static async Task<(bool Ok, string Token, string Login, string Error)> LoginAsync(
        string authBaseUrl,
        string login,
        string password,
        CancellationToken ct = default)
    {
        try
        {
            var baseUri = Normalize(authBaseUrl);
            using var http = new HttpClient { BaseAddress = baseUri, Timeout = TimeSpan.FromSeconds(30) };
            http.DefaultRequestHeaders.TryAddWithoutValidation("X-Client-Realm", "roza");
            var body = JsonSerializer.Serialize(new { login = login.Trim(), password });
            using var res = await http
                .PostAsync("login", new StringContent(body, Encoding.UTF8, "application/json"), ct)
                .ConfigureAwait(false);
            var text = await res.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            if (!res.IsSuccessStatusCode)
                return (false, "", "", ParseError(text) ?? "Неверный логин или пароль.");

            using var doc = JsonDocument.Parse(text);
            var token = doc.RootElement.TryGetProperty("token", out var t) ? t.GetString() ?? "" : "";
            if (string.IsNullOrEmpty(token))
                return (false, "", "", "Сервер не вернул токен.");
            return (true, token, login.Trim(), "");
        }
        catch (Exception ex)
        {
            return (false, "", "", ex.Message);
        }
    }

    private static Uri Normalize(string url)
    {
        var t = url.Trim();
        if (!t.StartsWith("http", StringComparison.OrdinalIgnoreCase))
            t = "http://" + t;
        return new Uri(t.TrimEnd('/') + "/");
    }

    private static string? ParseError(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            if (doc.RootElement.TryGetProperty("error", out var e))
                return e.GetString();
        }
        catch
        {
            // ignore
        }

        return null;
    }
}
