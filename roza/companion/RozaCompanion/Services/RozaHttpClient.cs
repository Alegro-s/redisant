using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using RozaCompanion.Models;

namespace RozaCompanion.Services;

public sealed class RozaHttpClient : IDisposable
{
    private static readonly JsonSerializerOptions JsonRead = new() { PropertyNameCaseInsensitive = true };

    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromMinutes(15) };

    public void Dispose() => _http.Dispose();

    public async Task<bool> HealthOkAsync(Uri baseUri, CancellationToken ct)
    {
        try
        {
            var u = new Uri(baseUri, "api/health");
            var r = await _http.GetAsync(u, ct).ConfigureAwait(false);
            return r.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    public async Task<string?> TryGetHealthSummaryAsync(Uri baseUri, CancellationToken ct)
    {
        try
        {
            var u = new Uri(baseUri, "api/health");
            var r = await _http.GetAsync(u, ct).ConfigureAwait(false);
            if (!r.IsSuccessStatusCode)
                return null;
            var json = await r.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            using var doc = JsonDocument.Parse(json);
            return RozaHealthFormatter.Format(doc.RootElement);
        }
        catch
        {
            return null;
        }
    }

    public async Task<string?> TryGetHealthRawAsync(Uri baseUri, CancellationToken ct)
    {
        try
        {
            var u = new Uri(baseUri, "api/health");
            var r = await _http.GetAsync(u, ct).ConfigureAwait(false);
            if (!r.IsSuccessStatusCode)
                return null;
            return await r.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
        }
        catch
        {
            return null;
        }
    }

    public async Task<UiConfigDto?> TryGetUiConfigAsync(Uri baseUri, CancellationToken ct)
    {
        try
        {
            var u = new Uri(baseUri, "api/ui-config");
            var r = await _http.GetAsync(u, ct).ConfigureAwait(false);
            if (!r.IsSuccessStatusCode)
                return null;
            return await r.Content.ReadFromJsonAsync<UiConfigDto>(JsonRead, ct).ConfigureAwait(false);
        }
        catch
        {
            return null;
        }
    }

    public async Task<WorkspaceApiDto?> TryGetWorkspaceAsync(Uri baseUri, CancellationToken ct)
    {
        try
        {
            var u = new Uri(baseUri, "api/workspace");
            var r = await _http.GetAsync(u, ct).ConfigureAwait(false);
            if (!r.IsSuccessStatusCode)
                return null;
            return await r.Content.ReadFromJsonAsync<WorkspaceApiDto>(JsonRead, ct).ConfigureAwait(false);
        }
        catch
        {
            return null;
        }
    }

    public async Task<StudioDatasetsResponseDto?> TryGetStudioDatasetsAsync(Uri baseUri, CancellationToken ct)
    {
        try
        {
            var u = new Uri(baseUri, "api/studio/datasets");
            var r = await _http.GetAsync(u, ct).ConfigureAwait(false);
            if (!r.IsSuccessStatusCode)
                return null;
            return await r.Content.ReadFromJsonAsync<StudioDatasetsResponseDto>(JsonRead, ct).ConfigureAwait(false);
        }
        catch
        {
            return null;
        }
    }

    /// <summary>Произвольный JSON дерева навыков и метрик Studio (/api/studio/skills).</summary>
    public async Task<string?> TryGetStudioSkillsJsonAsync(Uri baseUri, CancellationToken ct)
    {
        try
        {
            var u = new Uri(baseUri, "api/studio/skills");
            var r = await _http.GetAsync(u, ct).ConfigureAwait(false);
            if (!r.IsSuccessStatusCode)
                return null;
            return await r.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
        }
        catch
        {
            return null;
        }
    }

    public Task<string> ChatPostAsync(
        Uri baseUri,
        string text,
        bool agent,
        string sessionId,
        string contextKey,
        CancellationToken ct)
        => ChatPostAsync(baseUri, text, agent, sessionId, contextKey, null, ct);

    public async Task<string> ChatPostAsync(
        Uri baseUri,
        string text,
        bool agent,
        string sessionId,
        string contextKey,
        IReadOnlyList<ChatAttachmentDto>? attachments,
        CancellationToken ct)
    {
        var dto = await ChatPostDetailedAsync(baseUri, text, agent, sessionId, contextKey, attachments, ct)
            .ConfigureAwait(false);
        return dto.Reply ?? "";
    }

    public Task<HttpChatResponseDto> ChatPostDetailedAsync(
        Uri baseUri,
        string text,
        bool agent,
        string sessionId,
        string contextKey,
        IReadOnlyList<ChatAttachmentDto>? attachments,
        CancellationToken ct)
        => ChatPostDetailedAsync(baseUri, text, agent, sessionId, contextKey, attachments, null, ct);

    public async Task<HttpChatResponseDto> ChatPostDetailedAsync(
        Uri baseUri,
        string text,
        bool agent,
        string sessionId,
        string contextKey,
        IReadOnlyList<ChatAttachmentDto>? attachments,
        string? bearerToken,
        CancellationToken ct)
    {
        var u = new Uri(baseUri, "api/chat");
        object payload = new
        {
            text,
            agent,
            session_id = sessionId,
            context_key = contextKey ?? "",
            attachments = attachments is { Count: > 0 }
                ? attachments
                : null,
        };
        using var req = new HttpRequestMessage(HttpMethod.Post, u)
        {
            Content = JsonContent.Create(payload),
        };
        if (!string.IsNullOrWhiteSpace(bearerToken))
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearerToken.Trim());
        var r = await _http.SendAsync(req, ct).ConfigureAwait(false);
        r.EnsureSuccessStatusCode();
        return await r.Content.ReadFromJsonAsync<HttpChatResponseDto>(cancellationToken: ct).ConfigureAwait(false)
               ?? new HttpChatResponseDto();
    }

    public async Task PushIntegrationAsync(
        Uri baseUri,
        string contextKey,
        string markdown,
        string? bearerToken,
        CancellationToken ct)
    {
        var u = new Uri(baseUri, "api/integration/context");
        using var req = new HttpRequestMessage(HttpMethod.Post, u)
        {
            Content = JsonContent.Create(new { context_key = contextKey, markdown }),
        };
        if (!string.IsNullOrWhiteSpace(bearerToken))
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearerToken.Trim());
        var r = await _http.SendAsync(req, ct).ConfigureAwait(false);
        r.EnsureSuccessStatusCode();
    }

    public async Task<LearningStatsDto?> TryGetLearningStatsAsync(Uri baseUri, CancellationToken ct)
    {
        try
        {
            var u = new Uri(baseUri, "api/learning/stats");
            var r = await _http.GetAsync(u, ct).ConfigureAwait(false);
            if (!r.IsSuccessStatusCode)
                return null;
            return await r.Content.ReadFromJsonAsync<LearningStatsDto>(JsonRead, ct).ConfigureAwait(false);
        }
        catch
        {
            return null;
        }
    }

    public async Task<bool> PostLearningEnabledAsync(Uri baseUri, bool enabled, CancellationToken ct)
    {
        try
        {
            var u = new Uri(baseUri, "api/learning/enabled");
            using var req = new HttpRequestMessage(HttpMethod.Post, u)
            {
                Content = JsonContent.Create(new { enabled }),
            };
            var r = await _http.SendAsync(req, ct).ConfigureAwait(false);
            return r.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    public async Task<bool> PostLlmPresetAsync(Uri baseUri, string preset, CancellationToken ct)
    {
        try
        {
            var u = new Uri(baseUri, "api/llm/preset");
            using var req = new HttpRequestMessage(HttpMethod.Post, u)
            {
                Content = JsonContent.Create(new { preset }),
            };
            var r = await _http.SendAsync(req, ct).ConfigureAwait(false);
            return r.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    public async Task<string?> UploadStudioDatasetAsync(
        Uri baseUri,
        Stream fileStream,
        string fileName,
        CancellationToken ct)
    {
        try
        {
            var u = new Uri(baseUri, "api/studio/datasets/upload");
            using var mp = new MultipartFormDataContent();
            var sc = new StreamContent(fileStream);
            sc.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");
            mp.Add(sc, "file", fileName);
            var r = await _http.PostAsync(u, mp, ct).ConfigureAwait(false);
            if (!r.IsSuccessStatusCode)
                return null;
            return await r.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
        }
        catch
        {
            return null;
        }
    }
}
