using System;
using System.IO;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace RozaCompanion.Services;

public sealed class CompanionLocalPrefs
{
    [JsonPropertyName("startup_wizard_completed")]
    public bool StartupWizardCompleted { get; set; } = true;

    [JsonPropertyName("server_url")]
    public string ServerUrl { get; set; } = "https://waypointclub.ru/roza/api";

    /// <summary>OpenAI-совместимый base URL (Gemini: …/v1beta/openai/ …).</summary>
    [JsonPropertyName("external_openai_base_url")]
    public string ExternalOpenAiBaseUrl { get; set; } = "";

    [JsonPropertyName("external_openai_api_key")]
    public string ExternalOpenAiApiKey { get; set; } = "";

    [JsonPropertyName("external_openai_model")]
    public string ExternalOpenAiModel { get; set; } = "gemini-2.0-flash";

    /// <summary>0 — Roza, 1 — внешний OpenAI-совместимый.</summary>
    [JsonPropertyName("chat_target_index")]
    public int ChatTargetIndex { get; set; }

    [JsonPropertyName("yandex_client_id")]
    public string YandexClientId { get; set; } = "";

    [JsonPropertyName("yandex_client_secret")]
    public string YandexClientSecret { get; set; } = "";

    [JsonPropertyName("yandex_tokens_json")]
    public string YandexTokensJson { get; set; } = "";

    /// <summary>0 — тёмная, 1 — светлая, 2 — как в системе (как в Waypoint Desktop).</summary>
    [JsonPropertyName("ui_theme")]
    public int UiTheme { get; set; } = 1;

    [JsonPropertyName("auth_token")]
    public string AuthToken { get; set; } = "";

    [JsonPropertyName("auth_login")]
    public string AuthLogin { get; set; } = "";

    [JsonPropertyName("auth_api_url")]
    public string AuthApiUrl { get; set; } = "https://waypointclub.ru/auth";

    [JsonPropertyName("account_url")]
    public string AccountUrl { get; set; } = "https://waypointclub.ru/roza/account";

    /// <summary>free | pro</summary>
    [JsonPropertyName("subscription_plan")]
    public string SubscriptionPlan { get; set; } = "free";

    [JsonPropertyName("tokens_used_today")]
    public int TokensUsedToday { get; set; }

    [JsonPropertyName("tokens_day_date")]
    public string TokensDayDate { get; set; } = "";
}

public static class CompanionLocalSettingsStore
{
    private static readonly JsonSerializerOptions Json = new()
    {
        WriteIndented = true,
    };

    public static string FilePath =>
        Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "RozaCompanion",
            "companion_settings.json");

    public static CompanionLocalPrefs Load()
    {
        try
        {
            var p = FilePath;
            if (!File.Exists(p))
                return new CompanionLocalPrefs();
            var json = File.ReadAllText(p);
            return JsonSerializer.Deserialize<CompanionLocalPrefs>(json, Json) ?? new CompanionLocalPrefs();
        }
        catch
        {
            return new CompanionLocalPrefs();
        }
    }

    public static void Save(CompanionLocalPrefs prefs)
    {
        try
        {
            var dir = Path.GetDirectoryName(FilePath);
            if (!string.IsNullOrEmpty(dir))
                Directory.CreateDirectory(dir);
            File.WriteAllText(FilePath, JsonSerializer.Serialize(prefs, Json));
        }
        catch
        {
            // ignore
        }
    }
}
