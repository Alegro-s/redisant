using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using RozaCompanion.Models;

namespace RozaCompanion.Services;

/// <summary>Клиент чата по тому же протоколу, что и веб-интерфейс Roza (/ws/chat).</summary>
public sealed class RozaSocketChat : IAsyncDisposable
{
    private ClientWebSocket? _ws;
    private CancellationTokenSource? _recvCts;
    private Task? _recvTask;

    public bool IsConnected => _ws?.State == WebSocketState.Open;

    public event Action? Thinking;

    /// <summary>Текст ответа и необработанный JSON usage (если сервер прислал).</summary>
    public event Action<string, string?>? Reply;

    public event Action<string>? Error;
    public event Action? Disconnected;

    public async Task ConnectAsync(Uri wsUri, CancellationToken ct = default)
    {
        await DisconnectAsync().ConfigureAwait(false);
        _ws = new ClientWebSocket();
        await _ws.ConnectAsync(wsUri, ct).ConfigureAwait(false);
        _recvCts = new CancellationTokenSource();
        var token = _recvCts.Token;
        _recvTask = Task.Run(() => ReceiveLoopAsync(token), token);
    }

    public async Task SendMessageAsync(
        string sessionId,
        string text,
        bool agent,
        string? contextKey,
        IReadOnlyList<ChatAttachmentDto>? attachments,
        CancellationToken ct = default)
    {
        if (_ws is not { State: WebSocketState.Open })
            throw new InvalidOperationException("WebSocket не подключён.");
        using var ms = new MemoryStream();
        await using (var writer = new Utf8JsonWriter(ms))
        {
            writer.WriteStartObject();
            writer.WriteString("type", "message");
            writer.WriteString("session_id", string.IsNullOrWhiteSpace(sessionId) ? "default" : sessionId.Trim());
            writer.WriteString("text", text);
            writer.WriteBoolean("agent", agent);
            if (!string.IsNullOrWhiteSpace(contextKey))
                writer.WriteString("context_key", contextKey.Trim());
            if (attachments is { Count: > 0 })
            {
                writer.WritePropertyName("attachments");
                writer.WriteStartArray();
                foreach (var a in attachments.Take(32))
                {
                    writer.WriteStartObject();
                    writer.WriteString("filename", string.IsNullOrWhiteSpace(a.Filename) ? "file" : a.Filename.Trim());
                    writer.WriteString("content", a.Content ?? "");
                    writer.WriteEndObject();
                }

                writer.WriteEndArray();
            }

            writer.WriteEndObject();
        }

        var bytes = ms.ToArray();
        await _ws.SendAsync(bytes, WebSocketMessageType.Text, true, ct).ConfigureAwait(false);
    }

    public async Task ResetAsync(string sessionId, CancellationToken ct = default)
    {
        if (_ws is not { State: WebSocketState.Open })
            return;
        var sid = string.IsNullOrWhiteSpace(sessionId) ? "default" : sessionId.Trim();
        var json = JsonSerializer.SerializeToUtf8Bytes(new Dictionary<string, string>
        {
            ["type"] = "reset",
            ["session_id"] = sid,
        });
        await _ws.SendAsync(json, WebSocketMessageType.Text, true, ct).ConfigureAwait(false);
    }

    private async Task ReceiveLoopAsync(CancellationToken ct)
    {
        var ws = _ws;
        if (ws is null)
            return;
        var buffer = new byte[16384];
        try
        {
            while (!ct.IsCancellationRequested && ws.State == WebSocketState.Open)
            {
                using var message = new MemoryStream();
                WebSocketReceiveResult res;
                do
                {
                    res = await ws
                        .ReceiveAsync(new ArraySegment<byte>(buffer), ct)
                        .ConfigureAwait(false);
                    if (res.MessageType == WebSocketMessageType.Close)
                    {
                        Disconnected?.Invoke();
                        return;
                    }

                    message.Write(buffer, 0, res.Count);
                } while (!res.EndOfMessage);

                var json = Encoding.UTF8.GetString(message.ToArray());
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                var type = root.GetProperty("type").GetString();
                switch (type)
                {
                    case "thinking":
                        Thinking?.Invoke();
                        break;
                    case "reply":
                    {
                        var replyText = root.GetProperty("text").GetString() ?? "";
                        string? usageRaw = null;
                        if (root.TryGetProperty("usage", out var ug)
                            && ug.ValueKind is not JsonValueKind.Null
                            && ug.ValueKind is not JsonValueKind.Undefined)
                            usageRaw = ug.GetRawText();
                        Reply?.Invoke(replyText, usageRaw);
                        break;
                    }
                    case "error":
                        Error?.Invoke(root.GetProperty("message").GetString() ?? "ошибка");
                        break;
                    case "reset_ok":
                        Reply?.Invoke("Сессия сброшена.", null);
                        break;
                }
            }
        }
        catch (OperationCanceledException)
        {
            // ignore
        }
        catch
        {
            Disconnected?.Invoke();
        }
    }

    public async ValueTask DisposeAsync()
    {
        try
        {
            _recvCts?.Cancel();
            if (_recvTask is not null)
                try
                {
                    await _recvTask.ConfigureAwait(false);
                }
                catch
                {
                    // ignore
                }

            if (_ws is { State: WebSocketState.Open })
                await _ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "bye", CancellationToken.None)
                    .ConfigureAwait(false);
        }
        catch
        {
            // ignore
        }
        finally
        {
            _ws?.Dispose();
            _ws = null;
            _recvCts?.Dispose();
            _recvCts = null;
            _recvTask = null;
        }
    }

    public async Task DisconnectAsync()
    {
        await DisposeAsync().ConfigureAwait(false);
    }
}
