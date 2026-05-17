using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using RozaCompanion.Models;

namespace RozaCompanion.Services;

public static class ChatSessionStore
{
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
    };

    public static string StorePath =>
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "RozaCompanion",
            "chat_sessions.json");

    public static CompanionSessionsFileDto Load()
    {
        try
        {
            var path = StorePath;
            if (!File.Exists(path))
                return new CompanionSessionsFileDto();

            var json = File.ReadAllText(path);
            return JsonSerializer.Deserialize<CompanionSessionsFileDto>(json, JsonOpts)
                   ?? new CompanionSessionsFileDto();
        }
        catch
        {
            return new CompanionSessionsFileDto();
        }
    }

    public static async Task<CompanionSessionsFileDto> LoadAsync(CancellationToken ct = default)
    {
        try
        {
            var path = StorePath;
            if (!File.Exists(path))
                return new CompanionSessionsFileDto();

            await using var fs = File.OpenRead(path);
            var dto = await JsonSerializer.DeserializeAsync<CompanionSessionsFileDto>(fs, JsonOpts, ct);
            return dto ?? new CompanionSessionsFileDto();
        }
        catch
        {
            return new CompanionSessionsFileDto();
        }
    }

    public static void Save(
        string? currentId,
        IReadOnlyList<SessionEntryVm> sessions,
        IReadOnlyDictionary<string, List<ChatLineVm>> logs)
    {
        var dir = Path.GetDirectoryName(StorePath);
        if (!string.IsNullOrEmpty(dir))
            Directory.CreateDirectory(dir);

        var dto = new CompanionSessionsFileDto { CurrentId = currentId };
        foreach (var s in sessions.OrderByDescending(x => x.UpdatedUnixMs))
        {
            logs.TryGetValue(s.Id, out var msgs);
            dto.Sessions.Add(new StoredChatSessionDto
            {
                Id = s.Id,
                Title = s.Title,
                UpdatedUnixMs = s.UpdatedUnixMs,
                Messages = (msgs ?? new List<ChatLineVm>())
                    .Select(m => new StoredChatLineDto { Role = m.Role, Text = m.Text, Cls = m.Cls })
                    .ToList(),
            });
        }

        var json = JsonSerializer.Serialize(dto, JsonOpts);
        File.WriteAllText(StorePath, json);
    }

    public static async Task SaveAsync(
        string? currentId,
        IReadOnlyList<SessionEntryVm> sessions,
        IReadOnlyDictionary<string, List<ChatLineVm>> logs,
        CancellationToken ct = default)
    {
        var dir = Path.GetDirectoryName(StorePath);
        if (!string.IsNullOrEmpty(dir))
            Directory.CreateDirectory(dir);

        var dto = new CompanionSessionsFileDto { CurrentId = currentId };
        foreach (var s in sessions.OrderByDescending(x => x.UpdatedUnixMs))
        {
            logs.TryGetValue(s.Id, out var msgs);
            dto.Sessions.Add(new StoredChatSessionDto
            {
                Id = s.Id,
                Title = s.Title,
                UpdatedUnixMs = s.UpdatedUnixMs,
                Messages = (msgs ?? new List<ChatLineVm>())
                    .Select(m => new StoredChatLineDto { Role = m.Role, Text = m.Text, Cls = m.Cls })
                    .ToList(),
            });
        }

        await using var fs = File.Create(StorePath);
        await JsonSerializer.SerializeAsync(fs, dto, JsonOpts, ct);
    }
}
