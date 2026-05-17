using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace RozaCompanion.Models;

public sealed class EventsFileDto
{
    [JsonPropertyName("events")]
    public List<CompanionEventDto> Events { get; set; } = new();
}

public sealed class CompanionEventDto
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = "";

    [JsonPropertyName("title")]
    public string Title { get; set; } = "";

    [JsonPropertyName("start")]
    public string Start { get; set; } = "";

    [JsonPropertyName("end")]
    public string End { get; set; } = "";

    [JsonPropertyName("notes")]
    public string Notes { get; set; } = "";
}

public sealed class HttpChatResponseDto
{
    [JsonPropertyName("reply")]
    public string Reply { get; set; } = "";

    [JsonPropertyName("session_id")]
    public string SessionId { get; set; } = "";

    [JsonPropertyName("usage")]
    public JsonElement Usage { get; set; }
}

public sealed class ChatAttachmentDto
{
    [JsonPropertyName("filename")]
    public string Filename { get; set; } = "";

    [JsonPropertyName("content")]
    public string Content { get; set; } = "";
}

public sealed class ChatLineVm
{
    public string Role { get; set; } = "";
    public string Text { get; set; } = "";

    [JsonPropertyName("cls")]
    public string Cls { get; set; } = "";

    /// <summary>Ответы ассистента рендерим как Markdown; пользователь и служебные строки — как текст.</summary>
    public bool IsMarkdownBubble =>
        Cls != "meta" && Role is "Roza" or "Модель (API)";
}

public sealed class UiConfigDto
{
    [JsonPropertyName("assistant_name")]
    public string AssistantName { get; set; } = "";

    [JsonPropertyName("assistant_think_first")]
    public bool AssistantThinkFirst { get; set; }

    [JsonPropertyName("assistant_swarm_prompt")]
    public bool AssistantSwarmPrompt { get; set; }

    [JsonPropertyName("tts_provider")]
    public string TtsProvider { get; set; } = "";
}

public sealed class WorkspaceApiDto
{
    [JsonPropertyName("roots")]
    public List<string> Roots { get; set; } = new();

    [JsonPropertyName("hint")]
    public string? Hint { get; set; }
}

public sealed class StudioDatasetFileDto
{
    [JsonPropertyName("name")]
    public string Name { get; set; } = "";

    [JsonPropertyName("size")]
    public long Size { get; set; }
}

public sealed class StudioDatasetsResponseDto
{
    [JsonPropertyName("dir")]
    public string Dir { get; set; } = "";

    [JsonPropertyName("files")]
    public List<StudioDatasetFileDto> Files { get; set; } = new();
}

public sealed class LearningStatsDto
{
    [JsonPropertyName("enabled")]
    public bool Enabled { get; set; }

    [JsonPropertyName("persisted_in_config")]
    public bool PersistedInConfig { get; set; }

    [JsonPropertyName("log_path")]
    public string LogPath { get; set; } = "";

    [JsonPropertyName("lines")]
    public int Lines { get; set; }

    [JsonPropertyName("bytes")]
    public long Bytes { get; set; }
}
