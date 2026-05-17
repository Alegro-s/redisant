using System.Text;
using System.Text.Json;

namespace RozaCompanion.Services;

public static class RozaHealthFormatter
{
    public static string Format(JsonElement h)
    {
        var sb = new StringBuilder();
        if (h.TryGetProperty("llm_backend", out var b))
            sb.AppendLine("Бэкенд LLM: " + (b.GetString() ?? "?"));

        if (h.TryGetProperty("ok", out var ok))
            sb.AppendLine("Готовность: " + (ok.GetBoolean() ? "да" : "нет"));

        if (h.TryGetProperty("ollama", out var oll) && oll.ValueKind == JsonValueKind.String)
            sb.AppendLine("Ollama: " + (oll.GetString() ?? ""));

        if (h.TryGetProperty("openai", out var oa) && oa.ValueKind == JsonValueKind.String)
            sb.AppendLine("OpenAI-совместимый: " + (oa.GetString() ?? ""));

        if (h.TryGetProperty("status_code", out var sc) && sc.ValueKind == JsonValueKind.Number)
            sb.AppendLine("HTTP-код: " + sc.GetInt32());

        if (h.TryGetProperty("model_path", out var mp) && mp.ValueKind == JsonValueKind.String)
            sb.AppendLine("Модель: " + mp.GetString());

        if (h.TryGetProperty("model_id", out var mid) && mid.ValueKind == JsonValueKind.String)
            sb.AppendLine("model_id: " + mid.GetString());

        if (h.TryGetProperty("preset_light", out var pl) && pl.ValueKind == JsonValueKind.String)
        {
            var t = pl.GetString();
            if (!string.IsNullOrEmpty(t))
                sb.AppendLine("preset_light: " + t);
        }

        if (h.TryGetProperty("preset_strong", out var ps) && ps.ValueKind == JsonValueKind.String)
        {
            var t = ps.GetString();
            if (!string.IsNullOrEmpty(t))
                sb.AppendLine("preset_strong: " + t);
        }

        if (h.TryGetProperty("hint", out var hint) && hint.ValueKind == JsonValueKind.String)
        {
            var t = hint.GetString();
            if (!string.IsNullOrEmpty(t))
                sb.AppendLine(t);
        }

        return sb.Length == 0 ? h.ToString() : sb.ToString().TrimEnd();
    }
}
