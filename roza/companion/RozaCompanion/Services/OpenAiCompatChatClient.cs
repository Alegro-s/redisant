using System;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;

namespace RozaCompanion.Services;

/// <summary>Один запрос к OpenAI-совместимому Chat Completions (Google Gemini OpenAI API, LM Studio, vLLM…).</summary>
public static class OpenAiCompatChatClient
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromMinutes(10) };

    public static async Task<(string Reply, string? UsageHint)> ChatAsync(
        Uri baseUrl,
        string apiKey,
        string model,
        string userMessage,
        CancellationToken ct)
    {
        // OpenAI: …/v1/chat/completions. Gemini OpenAI: …/v1beta/openai/chat/completions (уже содержит openai).
        var root = baseUrl.ToString().TrimEnd('/');
        if (!root.EndsWith("/v1", StringComparison.OrdinalIgnoreCase)
            && !root.Contains("/openai/", StringComparison.OrdinalIgnoreCase)
            && !root.EndsWith("/openai", StringComparison.OrdinalIgnoreCase))
            root += "/v1";

        var url = new Uri($"{root.TrimEnd('/')}/chat/completions");
        using var req = new HttpRequestMessage(HttpMethod.Post, url);
        if (!string.IsNullOrWhiteSpace(apiKey))
            req.Headers.TryAddWithoutValidation("Authorization", "Bearer " + apiKey.Trim());
        req.Content = JsonContent.Create(
            new
            {
                model = string.IsNullOrWhiteSpace(model) ? "gpt-4o-mini" : model.Trim(),
                messages = new[] { new { role = "user", content = userMessage } },
                max_tokens = 16384,
            });

        using var resp = await Http.SendAsync(req, ct).ConfigureAwait(false);
        var body = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
        if (!resp.IsSuccessStatusCode)
            throw new InvalidOperationException($"HTTP {(int)resp.StatusCode}: {body[..Math.Min(400, body.Length)]}");

        using var doc = JsonDocument.Parse(body);
        var r = doc.RootElement;
        string reply = "";
        if (r.TryGetProperty("choices", out var ch) && ch.GetArrayLength() > 0)
        {
            var m = ch[0].GetProperty("message");
            reply = m.GetProperty("content").GetString() ?? "";
        }

        string? usage = null;
        if (r.TryGetProperty("usage", out var u))
        {
            var pt = u.TryGetProperty("prompt_tokens", out var a) ? a.GetInt32() : (int?)null;
            var ctok = u.TryGetProperty("completion_tokens", out var b) ? b.GetInt32() : (int?)null;
            var tot = u.TryGetProperty("total_tokens", out var c) ? c.GetInt32() : (int?)null;
            if (pt is not null || ctok is not null || tot is not null)
                usage = $"prompt {pt ?? 0} · completion {ctok ?? 0} · всего {tot ?? 0}";
        }

        return (reply.Trim(), usage);
    }
}
