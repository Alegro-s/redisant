using System;
using System.IO;
using System.Text.Json;
using RozaCompanion.Models;

namespace RozaCompanion.Services;

public static class LocalEventStore
{
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    };

    public static string GetPath()
    {
        var dir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "RozaCompanion");
        Directory.CreateDirectory(dir);
        return Path.Combine(dir, "events.json");
    }

    public static EventsFileDto Load()
    {
        var p = GetPath();
        if (!File.Exists(p))
            return new EventsFileDto();
        try
        {
            var raw = File.ReadAllText(p);
            var d = JsonSerializer.Deserialize<EventsFileDto>(raw, JsonOpts);
            return d ?? new EventsFileDto();
        }
        catch
        {
            return new EventsFileDto();
        }
    }

    public static void Save(EventsFileDto data)
    {
        var p = GetPath();
        File.WriteAllText(p, JsonSerializer.Serialize(data, JsonOpts));
    }
}
