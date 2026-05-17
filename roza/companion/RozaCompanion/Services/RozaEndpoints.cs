using System;

namespace RozaCompanion.Services;

public static class RozaEndpoints
{
    public static Uri HttpBase(string userInput)
    {
        var t = userInput.Trim();
        if (string.IsNullOrEmpty(t))
            t = "http://127.0.0.1:8765";
        if (!t.StartsWith("http://", StringComparison.OrdinalIgnoreCase)
            && !t.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            t = "http://" + t;
        return new Uri(t.TrimEnd('/') + "/");
    }

    public static Uri WebSocketChatUri(Uri httpBase)
    {
        var b = new UriBuilder(httpBase)
        {
            Scheme = httpBase.Scheme.Equals("https", StringComparison.OrdinalIgnoreCase) ? "wss" : "ws",
            Path = "/ws/chat",
        };
        return b.Uri;
    }
}
