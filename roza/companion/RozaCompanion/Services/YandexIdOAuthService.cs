using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace RozaCompanion.Services;

/// <summary>OAuth 2.0 Яндекс ID с loopback redirect (добавьте в приложении Яндекс redirect URI).</summary>
public static class YandexIdOAuthService
{
    /// <summary>Зарегистрируйте этот redirect в кабинете Яндекс OAuth для типа «Веб-сервисы» или «Установленное приложение».</summary>
    public const string DefaultRedirectUri = "http://127.0.0.1:18769/";

    public static async Task<(bool Ok, string Message, string? TokensJson)> LoginAsync(
        string clientId,
        string? clientSecret,
        CancellationToken ct)
    {
        var cid = clientId.Trim();
        if (string.IsNullOrEmpty(cid))
            return (false, "Укажите Client ID приложения Яндекс OAuth.", null);

        HttpListener? listener = null;
        try
        {
            listener = new HttpListener();
            listener.Prefixes.Add(DefaultRedirectUri);
            listener.Start();
        }
        catch (Exception ex)
        {
            return (false, "Не удалось занять порт 18769 для OAuth: " + ex.Message, null);
        }

        try
        {
            var state = Guid.NewGuid().ToString("N");
            var auth = new StringBuilder("https://oauth.yandex.ru/authorize?");
            auth.Append("response_type=code");
            auth.Append("&client_id=").Append(Uri.EscapeDataString(cid));
            auth.Append("&redirect_uri=").Append(Uri.EscapeDataString(DefaultRedirectUri));
            auth.Append("&state=").Append(Uri.EscapeDataString(state));
            auth.Append("&force_confirm=yes");

            Process.Start(new ProcessStartInfo { FileName = auth.ToString(), UseShellExecute = true });

            string? code = null;
            string? err = null;
            var deadline = DateTime.UtcNow.AddMinutes(3);
            while (DateTime.UtcNow < deadline && code is null && err is null)
            {
                ct.ThrowIfCancellationRequested();
                var ctx = await Task.Run(() => listener.GetContext(), ct).ConfigureAwait(false);
                var req = ctx.Request;
                var res = ctx.Response;
                if (req.QueryString.Get("state") != state)
                {
                    res.StatusCode = 400;
                    var buf = Encoding.UTF8.GetBytes("state mismatch");
                    await res.OutputStream.WriteAsync(buf, ct).ConfigureAwait(false);
                    res.Close();
                    continue;
                }

                err = req.QueryString.Get("error");
                code = req.QueryString.Get("code");
                var html = code is not null
                    ? "<html><body>Можно закрыть окно и вернуться в Stanza.</body></html>"
                    : "<html><body>Ошибка авторизации. Закройте окно.</body></html>";
                var b = Encoding.UTF8.GetBytes(html);
                res.ContentType = "text/html; charset=utf-8";
                res.ContentLength64 = b.Length;
                await res.OutputStream.WriteAsync(b, ct).ConfigureAwait(false);
                res.Close();
                break;
            }

            if (!string.IsNullOrEmpty(err))
                return (false, "Яндекс вернул ошибку: " + err, null);
            if (string.IsNullOrEmpty(code))
                return (false, "Код авторизации не получен (время истекло или окно закрыто).", null);

            using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(40) };
            var form = new List<KeyValuePair<string, string>>
            {
                new("grant_type", "authorization_code"),
                new("code", code),
                new("client_id", cid),
                new("redirect_uri", DefaultRedirectUri),
            };
            if (!string.IsNullOrWhiteSpace(clientSecret))
                form.Add(new KeyValuePair<string, string>("client_secret", clientSecret.Trim()));

            using var resp = await http.PostAsync(
                    "https://oauth.yandex.ru/token",
                    new FormUrlEncodedContent(form),
                    ct)
                .ConfigureAwait(false);
            var body = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode)
                return (false, $"Обмен кода: HTTP {(int)resp.StatusCode} {body[..Math.Min(200, body.Length)]}", null);

            return (true, "Вход выполнен, токены сохранены локально.", body);
        }
        finally
        {
            try
            {
                listener.Stop();
            }
            catch
            {
                // ignore
            }

            listener.Close();
        }
    }
}
