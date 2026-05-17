using System;
using System.Collections.Generic;
using System.Text.Json.Serialization;
using CommunityToolkit.Mvvm.ComponentModel;

namespace RozaCompanion.Models;

public sealed class CompanionSessionsFileDto
{
    [JsonPropertyName("currentId")]
    public string? CurrentId { get; set; }

    [JsonPropertyName("sessions")]
    public List<StoredChatSessionDto> Sessions { get; set; } = new();
}

public sealed class StoredChatSessionDto
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = "";

    [JsonPropertyName("title")]
    public string Title { get; set; } = "Новый чат";

    [JsonPropertyName("updated")]
    public long UpdatedUnixMs { get; set; }

    [JsonPropertyName("messages")]
    public List<StoredChatLineDto> Messages { get; set; } = new();
}

public sealed class StoredChatLineDto
{
    [JsonPropertyName("role")]
    public string Role { get; set; } = "";

    [JsonPropertyName("text")]
    public string Text { get; set; } = "";

    [JsonPropertyName("cls")]
    public string Cls { get; set; } = "user";
}

public sealed class SessionEntryVm : ObservableObject
{
    public string Id { get; }

    private string _title;

    public string Title
    {
        get => _title;
        set => SetProperty(ref _title, value);
    }

    private long _updatedUnixMs;

    public long UpdatedUnixMs
    {
        get => _updatedUnixMs;
        set
        {
            if (SetProperty(ref _updatedUnixMs, value))
                OnPropertyChanged(nameof(UpdatedLabel));
        }
    }

    public string UpdatedLabel =>
        DateTimeOffset.FromUnixTimeMilliseconds(UpdatedUnixMs).ToLocalTime().ToString("g");

    public SessionEntryVm(string id, string title, long updatedUnixMs)
    {
        Id = id;
        _title = title;
        _updatedUnixMs = updatedUnixMs;
    }

    public void TouchNow() =>
        UpdatedUnixMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
}
