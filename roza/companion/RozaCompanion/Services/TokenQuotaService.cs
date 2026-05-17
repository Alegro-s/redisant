using System;

namespace RozaCompanion.Services;

public static class TokenQuotaService
{
    public const int FreeDailyTokenLimit = 8_000;
    public const int ProDailyTokenLimit = 200_000;

    public static int LimitForPlan(string? plan) =>
        string.Equals(plan, "pro", StringComparison.OrdinalIgnoreCase) ? ProDailyTokenLimit : FreeDailyTokenLimit;

    public static void ResetIfNewDay(CompanionLocalPrefs prefs)
    {
        var today = DateTime.UtcNow.ToString("yyyy-MM-dd");
        if (prefs.TokensDayDate != today)
        {
            prefs.TokensDayDate = today;
            prefs.TokensUsedToday = 0;
        }
    }

    public static bool CanSpend(CompanionLocalPrefs prefs, int estimatedTokens, out string message)
    {
        ResetIfNewDay(prefs);
        var limit = LimitForPlan(prefs.SubscriptionPlan);
        if (prefs.TokensUsedToday + estimatedTokens <= limit)
        {
            message = "";
            return true;
        }

        message =
            $"Дневной лимит ({limit:N0} токенов) исчерпан. Оформите подписку Roza AI в личном кабинете на сайте — для бытовых задач: документы, ПК и обучение.";
        return false;
    }

    public static void RecordUsage(CompanionLocalPrefs prefs, int tokens)
    {
        ResetIfNewDay(prefs);
        prefs.TokensUsedToday += Math.Max(0, tokens);
    }

    public static string QuotaLabel(CompanionLocalPrefs prefs)
    {
        ResetIfNewDay(prefs);
        var limit = LimitForPlan(prefs.SubscriptionPlan);
        var left = Math.Max(0, limit - prefs.TokensUsedToday);
        var plan = string.Equals(prefs.SubscriptionPlan, "pro", StringComparison.OrdinalIgnoreCase) ? "Подписка" : "Бесплатно";
        return $"{plan} · осталось ~{left:N0} / {limit:N0} токенов сегодня";
    }

    public static int EstimateTokens(string userText, string? reply = null) =>
        Math.Max(80, (userText.Length + (reply?.Length ?? 0)) / 4);
}
