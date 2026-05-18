using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Styling;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Media;
using Avalonia.Platform.Storage;
using Avalonia.Input.Platform;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RozaCompanion.Models;
using RozaCompanion.Services;

namespace RozaCompanion.ViewModels;

public partial class MainWindowViewModel : ViewModelBase
{
    private readonly RozaHttpClient _http = new();
    private readonly Dictionary<string, List<ChatLineVm>> _sessionLogs = new();
    private RozaSocketChat? _socket;
    private CancellationTokenSource? _socketCts;
    private string _currentSessionId = "";
    private bool _initVmDone;
    private bool _suppressSelectedSessionHandler;
    private bool _suppressLearningSync;
    private bool _prefsHydrating;

    private static readonly IBrush LearningOnBrush = new SolidColorBrush(Color.Parse("#34C759"));
    private static readonly IBrush LearningOffBrush = new SolidColorBrush(Color.Parse("#C7C7CC"));

    [ObservableProperty] private string _serverUrl = "https://waypointclub.ru/roza/api";

    [ObservableProperty] private bool _agentMode;

    [ObservableProperty] private bool _useWebSocket = true;

    [ObservableProperty] private string _statusText = "Подключите сервер Roza для работы с документами и обучением.";

    [ObservableProperty] private string _contextKey = "";

    [ObservableProperty] private string _integrationToken = "";

    [ObservableProperty] private string _integrationMarkdown = "";

    [ObservableProperty] private string _chatInput = "";

    [ObservableProperty] private string _sessionId = "";

    [ObservableProperty] private string _rozaProjectPath = "";

    [ObservableProperty] private string _dashboardPath = "";

    [ObservableProperty] private bool _isBusy;

    [ObservableProperty] private int _shellSection;

    [ObservableProperty] private bool _serverOnline;

    [ObservableProperty] private bool _socketConnected;

    /// <summary>Краткий статус связи для сайдбара (без «API да/нет»).</summary>
    [ObservableProperty] private string _connectionSummary = "Сервер ещё не проверен.";

    [ObservableProperty] private string _healthDetailText = "Подключитесь к серверу, чтобы увидеть /api/health.";

    [ObservableProperty] private string _brainModesText = "";

    [ObservableProperty] private string _workspaceInsightText = "";

    [ObservableProperty] private string _trainingDatasetsText =
        "Список появится после «Обновить» (нужен запущенный сервер).";

    [ObservableProperty] private string _trainingSkillsText = "";

    [ObservableProperty] private string _learningAnalyticsText = "Подключитесь к серверу — загрузим /api/learning/stats.";

    [ObservableProperty] private bool _learningRecordingEnabled;

    [ObservableProperty] private IBrush _learningLedBrush = new SolidColorBrush(Color.Parse("#C7C7CC"));

    [ObservableProperty] private string _learningLedCaption = "журнал: неизвестно";

    [ObservableProperty] private string _llmPresetHint = "Пресеты модели настраиваются в config.yaml сервера Roza.";

    /// <summary>0 — сервер Roza, 1 — внешний OpenAI-совместимый API.</summary>
    [ObservableProperty] private int _chatTargetIndex;

    [ObservableProperty] private string _externalOpenAiBaseUrl = "";

    [ObservableProperty] private string _externalOpenAiApiKey = "";

    [ObservableProperty] private string _externalOpenAiModel = "gemini-2.0-flash";

    [ObservableProperty] private string _yandexClientId = "";

    [ObservableProperty] private string _yandexClientSecret = "";

    [ObservableProperty] private string _yandexLoginHint =
        "Вход через Яндекс ID. Настройте приложение в кабинете разработчика Яндекса и укажите Client ID в настройках.";

    [ObservableProperty] private bool _showStartupWizard;

    [ObservableProperty] private string _startupProbeText = "Проверьте подключение к серверу Roza.";

    [ObservableProperty] private string _lastTokenUsageText = "";

    [ObservableProperty] private SessionEntryVm? _selectedSession;

    public ObservableCollection<ChatLineVm> ChatLines { get; } = new();

    public ObservableCollection<SessionEntryVm> Sessions { get; } = new();

    public ObservableCollection<ChatAttachmentItemVm> PendingChatAttachments { get; } = new();

    public ObservableCollection<LearningTrackVm> LearningTracks { get; } = new();

    public const string BrandName = "Roza AI";

    public const string BrandSubtitle = "Консультант";

    [ObservableProperty] private string _sessionContextLine = "";

    [ObservableProperty] private string _lastRepoFolderLabel = "";

    [ObservableProperty] private string _changesPanelHint = "Отчёты по изменениям в проекте появятся после синхронизации с сервером.";

    /// <summary>0 — тёмная, 1 — светлая, 2 — системная.</summary>
    [ObservableProperty] private int _uiThemeIndex;

    /// <summary>Вкладка категорий в экране настроек (левая колонка).</summary>
    [ObservableProperty] private int _settingsCategoryIndex;

    [ObservableProperty] private string _settingsCategoryTitle = "Общее";

    [ObservableProperty] private bool _chatHasMessages;

    [ObservableProperty] private string _tokenQuotaLine = "";

    [ObservableProperty] private string _authLoginLine = "";

    [ObservableProperty] private bool _externalApiUnlocked;

    /// <summary>Событие: аргумент true — применить светлую тему.</summary>
    public event Action<bool>? ApplyThemeRequested;

    public MainWindowViewModel()
    {
        var file = ChatSessionStore.Load();
        foreach (var s in file.Sessions)
        {
            var entry = new SessionEntryVm(s.Id, s.Title, s.UpdatedUnixMs);
            Sessions.Add(entry);
            _sessionLogs[s.Id] = s.Messages
                .Select(m => new ChatLineVm { Role = m.Role, Text = m.Text, Cls = string.IsNullOrEmpty(m.Cls) ? "" : m.Cls })
                .ToList();
        }

        if (Sessions.Count == 0)
        {
            var id = NewSessionId();
            var entry = new SessionEntryVm(id, "Новый чат", NowMs());
            Sessions.Add(entry);
            _sessionLogs[id] = new List<ChatLineVm>();
        }

        var pick = file.CurrentId is { } cid && _sessionLogs.ContainsKey(cid)
            ? Sessions.FirstOrDefault(x => x.Id == cid)
            : Sessions[0];

        if (pick is null)
            pick = Sessions[0];

        foreach (var line in _sessionLogs[pick.Id])
            ChatLines.Add(line);

        _currentSessionId = pick.Id;
        SessionId = pick.Id;
        _suppressSelectedSessionHandler = true;
        SelectedSession = pick;
        _suppressSelectedSessionHandler = false;

        _prefsHydrating = true;
        var lp = CompanionLocalSettingsStore.Load();
        if (!string.IsNullOrWhiteSpace(lp.ServerUrl))
            ServerUrl = lp.ServerUrl.Trim();
        ExternalOpenAiBaseUrl = lp.ExternalOpenAiBaseUrl ?? "";
        ExternalOpenAiApiKey = lp.ExternalOpenAiApiKey ?? "";
        ExternalOpenAiModel = string.IsNullOrWhiteSpace(lp.ExternalOpenAiModel)
            ? "gemini-2.0-flash"
            : lp.ExternalOpenAiModel.Trim();
        ChatTargetIndex = lp.ChatTargetIndex is >= 0 and <= 1 ? lp.ChatTargetIndex : 0;
        YandexClientId = lp.YandexClientId ?? "";
        YandexClientSecret = lp.YandexClientSecret ?? "";
        UiThemeIndex = lp.UiTheme is >= 0 and <= 2 ? lp.UiTheme : 1;
        ShowStartupWizard = !lp.StartupWizardCompleted;
        if (!IsProPlan(lp) && lp.ChatTargetIndex == 1)
            lp.ChatTargetIndex = 0;
        _prefsHydrating = false;

        ChatLines.CollectionChanged += (_, _) => ChatHasMessages = ChatLines.Count > 0;
        ChatHasMessages = ChatLines.Count > 0;

        _initVmDone = true;
        SeedLearningTracks();
        RefreshQuotaUi();
        RefreshSessionContextLine();
        RefreshConnectionSummary();
    }

    partial void OnSessionIdChanged(string value) => RefreshConnectionSummary();

    partial void OnServerUrlChanged(string value)
    {
        if (_prefsHydrating || !_initVmDone)
            return;
        SaveLocalPrefs();
    }

    partial void OnExternalOpenAiBaseUrlChanged(string value)
    {
        if (_prefsHydrating || !_initVmDone)
            return;
        SaveLocalPrefs();
    }

    partial void OnExternalOpenAiApiKeyChanged(string value)
    {
        if (_prefsHydrating || !_initVmDone)
            return;
        SaveLocalPrefs();
    }

    partial void OnExternalOpenAiModelChanged(string value)
    {
        if (_prefsHydrating || !_initVmDone)
            return;
        SaveLocalPrefs();
        RefreshSessionContextLine();
    }

    partial void OnYandexClientIdChanged(string value)
    {
        if (_prefsHydrating || !_initVmDone)
            return;
        SaveLocalPrefs();
    }

    partial void OnYandexClientSecretChanged(string value)
    {
        if (_prefsHydrating || !_initVmDone)
            return;
        SaveLocalPrefs();
    }

    partial void OnChatTargetIndexChanged(int value)
    {
        if (_prefsHydrating || !_initVmDone)
            return;
        var prefs = CompanionLocalSettingsStore.Load();
        if (value == 1 && !IsProPlan(prefs))
        {
            _prefsHydrating = true;
            ChatTargetIndex = 0;
            _prefsHydrating = false;
            StatusText = "Внешние модели по API доступны с подпиской Roza AI — оформите в личном кабинете на сайте.";
            return;
        }

        SaveLocalPrefs();
        RefreshSessionContextLine();
    }

    partial void OnAgentModeChanged(bool value)
    {
        if (!_initVmDone)
            return;
        RefreshSessionContextLine();
    }

    partial void OnShellSectionChanged(int value)
    {
        if (!_initVmDone)
            return;
        if (value == 1)
            _ = RefreshTrainingCatalogAsync();
        if (value == 3)
            _ = RefreshInsights();
        if (value == 2)
            SettingsCategoryIndex = 0;
    }

    partial void OnServerOnlineChanged(bool value) => RefreshConnectionSummary();

    partial void OnSocketConnectedChanged(bool value) => RefreshConnectionSummary();

    partial void OnUseWebSocketChanged(bool value) => RefreshConnectionSummary();

    private void RefreshConnectionSummary()
    {
        if (!ServerOnline)
        {
            ConnectionSummary = "Сервер недоступен. Проверьте интернет и нажмите «Подключить».";
            return;
        }

        if (UseWebSocket)
        {
            ConnectionSummary = SocketConnected
                ? "Сервер: онлайн · ответы в реальном времени."
                : "Сервер: онлайн · потоковый режим не подключён — нажмите «Подключить».";
        }
        else
        {
            ConnectionSummary = "Сервер: онлайн · ответы по HTTP (сессия: «" + (SessionId.Trim().Length > 0 ? SessionId.Trim() : "default") + "»).";
        }
    }

    partial void OnSettingsCategoryIndexChanged(int value)
    {
        SettingsCategoryTitle = value switch
        {
            0 => "Общее",
            1 => "Сервер",
            2 => "Внешний API",
            3 => "Аккаунт",
            4 => "Контекст",
            5 => "Roza",
            6 => "Прочее",
            _ => "Настройки",
        };
    }

    partial void OnLearningRecordingEnabledChanged(bool value)
    {
        if (_suppressLearningSync || !_initVmDone)
            return;
        _ = PostLearningEnabledFireAndForgetAsync(value);
    }

    private async Task PostLearningEnabledFireAndForgetAsync(bool value)
    {
        var baseUri = RozaEndpoints.HttpBase(ServerUrl);
        if (!await _http.HealthOkAsync(baseUri, CancellationToken.None).ConfigureAwait(true))
        {
            _suppressLearningSync = true;
            LearningRecordingEnabled = !value;
            _suppressLearningSync = false;
            StatusText = "Сервер недоступен — режим журнала не изменён.";
            return;
        }

        var ok = await _http.PostLearningEnabledAsync(baseUri, value, CancellationToken.None).ConfigureAwait(true);
        if (!ok)
        {
            _suppressLearningSync = true;
            LearningRecordingEnabled = !value;
            _suppressLearningSync = false;
            StatusText = "Не удалось изменить режим журнала обучения.";
            return;
        }

        await RefreshLearningStatsAsync(baseUri).ConfigureAwait(true);
        StatusText = value ? "Журнал обучения включён (override сессии)." : "Журнал обучения выключен (override сессии).";
    }

    partial void OnSelectedSessionChanged(SessionEntryVm? value)
    {
        if (_suppressSelectedSessionHandler || !_initVmDone)
            return;

        _ = ApplySessionChangeAsync(value);
    }

    private async Task ApplySessionChangeAsync(SessionEntryVm? value)
    {
        try
        {
            SyncCurrentChatToLog();
            await DisconnectSocketAsync().ConfigureAwait(true);
            SocketConnected = false;
            ChatLines.Clear();
            _currentSessionId = value?.Id ?? "";
            SessionId = _currentSessionId;
            if (value is not null && _sessionLogs.TryGetValue(value.Id, out var list))
            {
                foreach (var line in list)
                    ChatLines.Add(line);
            }

            PersistSessions();
            RefreshSessionContextLine();
        }
        catch (Exception ex)
        {
            StatusText = "Сессия: " + ex.Message;
        }
    }

    [RelayCommand]
    private async Task NewChatAsync()
    {
        SyncCurrentChatToLog();
        await DisconnectSocketAsync().ConfigureAwait(true);
        SocketConnected = false;

        var id = NewSessionId();
        var entry = new SessionEntryVm(id, "Новый чат", NowMs());
        Sessions.Insert(0, entry);
        _sessionLogs[id] = new List<ChatLineVm>();
        ChatLines.Clear();
        _currentSessionId = id;
        SessionId = id;
        _suppressSelectedSessionHandler = true;
        SelectedSession = entry;
        _suppressSelectedSessionHandler = false;
        PersistSessions();
        RefreshSessionContextLine();
        StatusText = "Новая сессия. WebSocket отключён — нажмите «Подключить», если нужен потоковый режим.";
    }

    [RelayCommand]
    private async Task ConnectAsync()
    {
        var baseUri = RozaEndpoints.HttpBase(ServerUrl);
        IsBusy = true;
        try
        {
            var ok = await _http.HealthOkAsync(baseUri, CancellationToken.None).ConfigureAwait(true);
            ServerOnline = ok;
            if (!ok)
            {
                StatusText = "Сервер не отвечает. Проверьте адрес в настройках и подключение к интернету.";
                HealthDetailText = "Сервер недоступен.";
                return;
            }

            await PullInsightsFromServerAsync(baseUri).ConfigureAwait(true);
            await RefreshLearningStatsAsync(baseUri).ConfigureAwait(true);

            if (UseWebSocket)
            {
                await DisconnectSocketAsync().ConfigureAwait(true);
                _socketCts = new CancellationTokenSource();
                _socket = new RozaSocketChat();
                _socket.Thinking += OnSocketThinking;
                _socket.Reply += OnSocketReply;
                _socket.Error += OnSocketError;
                _socket.Disconnected += OnSocketDisconnected;
                var wsUri = RozaEndpoints.WebSocketChatUri(baseUri);
                await _socket.ConnectAsync(wsUri, _socketCts.Token).ConfigureAwait(true);
                SocketConnected = true;
                StatusText = "Подключено. Обмен сообщениями в реальном времени.";
            }
            else
            {
                SocketConnected = false;
                StatusText = "Сервер доступен. Можно отправлять сообщения.";
            }

            SaveLocalPrefs();
        }
        catch (Exception ex)
        {
            StatusText = "Ошибка: " + ex.Message;
            SocketConnected = false;
        }
        finally
        {
            IsBusy = false;
            RefreshConnectionSummary();
        }
    }

    [RelayCommand]
    private async Task RefreshInsights()
    {
        var baseUri = RozaEndpoints.HttpBase(ServerUrl);
        IsBusy = true;
        try
        {
            if (!await _http.HealthOkAsync(baseUri, CancellationToken.None).ConfigureAwait(true))
            {
                HealthDetailText = "Сервер недоступен.";
                return;
            }

            await PullInsightsFromServerAsync(baseUri).ConfigureAwait(true);
            await RefreshLearningStatsAsync(baseUri).ConfigureAwait(true);
            StatusText = "Панель аналитики обновлена.";
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private async Task DisconnectAsync()
    {
        await DisconnectSocketAsync().ConfigureAwait(true);
        SocketConnected = false;
        StatusText = "Отключено.";
        RefreshConnectionSummary();
    }

    [RelayCommand]
    private async Task ProbeStartupAsync()
    {
        IsBusy = true;
        try
        {
            var sb = new StringBuilder();
            var baseUri = RozaEndpoints.HttpBase(ServerUrl);
            var ok = await _http.HealthOkAsync(baseUri, CancellationToken.None).ConfigureAwait(true);
            sb.AppendLine(ok ? "Сервер Roza: доступен (/api/health)." : "Сервер Roza: нет ответа — запустите python -m roza web.");
            if (ok)
            {
                var h = await _http.TryGetHealthSummaryAsync(baseUri, CancellationToken.None).ConfigureAwait(true);
                if (!string.IsNullOrWhiteSpace(h))
                    sb.AppendLine(h);
            }

            if (!string.IsNullOrWhiteSpace(ExternalOpenAiBaseUrl.Trim()) && !string.IsNullOrWhiteSpace(ExternalOpenAiApiKey.Trim()))
                sb.AppendLine("Внешний API: base URL и ключ заданы (тестовый вызов не выполнялся, чтобы не расходовать токены).");
            else
                sb.AppendLine("Внешний API: можно указать позже в чате или настройках (Gemini OpenAI endpoint + ключ).");

            StartupProbeText = sb.ToString().Trim();
            StatusText = "Проверка готовности выполнена.";
        }
        catch (Exception ex)
        {
            StartupProbeText = "Ошибка проверки: " + ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private async Task CompleteStartupWizardAsync()
    {
        var cur = CompanionLocalSettingsStore.Load();
        cur.StartupWizardCompleted = true;
        cur.ServerUrl = ServerUrl.Trim();
        cur.ExternalOpenAiBaseUrl = ExternalOpenAiBaseUrl.Trim();
        cur.ExternalOpenAiApiKey = ExternalOpenAiApiKey;
        cur.ExternalOpenAiModel = ExternalOpenAiModel.Trim();
        cur.ChatTargetIndex = ChatTargetIndex;
        cur.YandexClientId = YandexClientId.Trim();
        cur.YandexClientSecret = YandexClientSecret;
        cur.UiTheme = UiThemeIndex;
        CompanionLocalSettingsStore.Save(cur);
        ShowStartupWizard = false;
        StatusText = "Подключаемся к серверу…";
        await ConnectAsync().ConfigureAwait(true);
    }

    [RelayCommand]
    private async Task AttachChatDocumentsAsync()
    {
        if (Application.Current?.ApplicationLifetime is not IClassicDesktopStyleApplicationLifetime life
            || life.MainWindow is not { } owner)
        {
            StatusText = "Не удалось открыть диалог вложений.";
            return;
        }

        var top = TopLevel.GetTopLevel(owner);
        if (top is null)
        {
            StatusText = "Не удалось открыть диалог вложений.";
            return;
        }

        var picked = await top.StorageProvider.OpenFilePickerAsync(
                new FilePickerOpenOptions
                {
                    Title = "Документы в контекст сообщения",
                    AllowMultiple = true,
                    FileTypeFilter = new List<FilePickerFileType>
                    {
                        new("Текст и код")
                        {
                            Patterns = new[]
                            {
                                "*.txt", "*.md", "*.json", "*.yaml", "*.yml", "*.py", "*.cs", "*.ts", "*.tsx",
                                "*.js", "*.html", "*.css", "*.xml",
                            },
                        },
                        FilePickerFileTypes.All,
                    },
                })
            .ConfigureAwait(true);

        if (picked is not { Count: > 0 })
        {
            StatusText = "Вложения не выбраны.";
            return;
        }

        const int maxPerFile = 512_000;
        const int maxFiles = 32;
        var n = 0;
        foreach (var file in picked.Take(maxFiles))
        {
            try
            {
                await using var stream = await file.OpenReadAsync().ConfigureAwait(true);
                using var reader = new StreamReader(stream);
                var body = await reader.ReadToEndAsync().ConfigureAwait(true);
                if (string.IsNullOrWhiteSpace(body))
                    continue;
                if (body.Length > maxPerFile)
                    body = body[..maxPerFile] + "\n…[обрезано в Companion]";
                var name = string.IsNullOrWhiteSpace(file.Name) ? "файл" : file.Name.Trim();
                PendingChatAttachments.Add(new ChatAttachmentItemVm(name, body, a => PendingChatAttachments.Remove(a)));
                n++;
            }
            catch (Exception ex)
            {
                StatusText = "Файл: " + ex.Message;
            }
        }

        StatusText = n > 0 ? $"К сообщению прикреплено файлов: {n}." : "Не удалось прочитать выбранные файлы.";
    }

    [RelayCommand]
    private async Task AttachRepositoryFolderAsync()
    {
        if (Application.Current?.ApplicationLifetime is not IClassicDesktopStyleApplicationLifetime life
            || life.MainWindow is not { } owner)
        {
            StatusText = "Не удалось открыть выбор папки.";
            return;
        }

        var top = TopLevel.GetTopLevel(owner);
        if (top is null)
        {
            StatusText = "Не удалось открыть выбор папки.";
            return;
        }

        var folders = await top.StorageProvider.OpenFolderPickerAsync(
                new FolderPickerOpenOptions { Title = "Корень репозитория для снимка", AllowMultiple = false })
            .ConfigureAwait(true);
        if (folders is not { Count: > 0 })
        {
            StatusText = "Выбор папки отменён.";
            return;
        }

        var local = folders[0].TryGetLocalPath();
        if (string.IsNullOrEmpty(local))
        {
            StatusText = "Не удалось получить локальный путь к папке.";
            return;
        }

        IsBusy = true;
        try
        {
            var md = RepositorySnapshotBuilder.Build(local);
            PendingChatAttachments.Add(
                new ChatAttachmentItemVm("__репозиторий__.md", md, a => PendingChatAttachments.Remove(a)));
            var t = local.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
            LastRepoFolderLabel = Path.GetFileName(t);
            if (string.IsNullOrEmpty(LastRepoFolderLabel))
                LastRepoFolderLabel = t;
            RefreshSessionContextLine();
            StatusText =
                "Снимок дерева и текстовых файлов добавлен во вложения. Отправьте вопрос — Roza увидит контекст (HTTP, WebSocket или внешний API).";
        }
        catch (Exception ex)
        {
            StatusText = "Репозиторий: " + ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private async Task LoginYandexAsync()
    {
        IsBusy = true;
        try
        {
            var (ok, msg, tokens) = await YandexIdOAuthService
                .LoginAsync(YandexClientId, YandexClientSecret, CancellationToken.None)
                .ConfigureAwait(true);
            if (!ok || tokens is null)
            {
                YandexLoginHint = msg;
                StatusText = msg;
                return;
            }

            var cur = CompanionLocalSettingsStore.Load();
            cur.YandexTokensJson = tokens;
            cur.YandexClientId = YandexClientId.Trim();
            cur.YandexClientSecret = YandexClientSecret;
            CompanionLocalSettingsStore.Save(cur);
            YandexLoginHint = msg + " Токены в локальном JSON.";
            StatusText = msg;
        }
        catch (Exception ex)
        {
            YandexLoginHint = ex.Message;
            StatusText = ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private void ApplyStarterPrompt(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
            return;
        ChatInput = text.Trim();
    }

    [RelayCommand]
    private void OpenSubscriptionInBrowser()
    {
        var url = CompanionLocalSettingsStore.Load().AccountUrl.Trim();
        if (string.IsNullOrEmpty(url))
            url = "https://waypointclub.ru/roza/account";
        try
        {
            Process.Start(new ProcessStartInfo(url) { UseShellExecute = true });
        }
        catch (Exception ex)
        {
            StatusText = ex.Message;
        }
    }

    [RelayCommand]
    private async Task SendAsync()
    {
        var text = ChatInput.Trim();
        if (string.IsNullOrEmpty(text) || IsBusy)
            return;

        var prefs = CompanionLocalSettingsStore.Load();
        var estimate = TokenQuotaService.EstimateTokens(text);
        if (!TokenQuotaService.CanSpend(prefs, estimate, out var quotaMsg))
        {
            AppendChatLine(new ChatLineVm { Role = "Roza AI", Text = quotaMsg, Cls = "meta" });
            StatusText = quotaMsg;
            RefreshQuotaUi();
            return;
        }

        var baseUri = RozaEndpoints.HttpBase(ServerUrl);
        var attachmentDtos = PendingChatAttachments
            .Select(a => new ChatAttachmentDto { Filename = a.Filename, Content = a.Content })
            .ToList();

        AppendChatLine(new ChatLineVm { Role = "Вы", Text = FormatOutgoingUserBubble(text, attachmentDtos) });
        ChatInput = "";
        IsBusy = true;
        LastTokenUsageText = "";

        try
        {
            if (ChatTargetIndex == 1)
            {
                var raw = ExternalOpenAiBaseUrl.Trim();
                if (string.IsNullOrEmpty(raw) || string.IsNullOrWhiteSpace(ExternalOpenAiApiKey))
                {
                    AppendChatLine(new ChatLineVm { Role = "Ошибка", Text = "Укажите base URL и API-ключ внешней модели (например Gemini OpenAI endpoint)." });
                    return;
                }

                if (!raw.StartsWith("http", StringComparison.OrdinalIgnoreCase))
                    raw = "https://" + raw;

                var openAiUri = new Uri(raw, UriKind.Absolute);
                var merged = MergeAttachmentsForProvider(text, attachmentDtos);
                StatusText = "Запрос к внешнему API…";
                var (reply, usageHint) = await OpenAiCompatChatClient
                    .ChatAsync(openAiUri, ExternalOpenAiApiKey.Trim(), ExternalOpenAiModel.Trim(), merged, CancellationToken.None)
                    .ConfigureAwait(true);
                AppendChatLine(new ChatLineVm { Role = "Модель (API)", Text = reply });
                if (!string.IsNullOrWhiteSpace(usageHint))
                {
                    LastTokenUsageText = "Внешняя: " + usageHint;
                    AppendChatLine(new ChatLineVm { Role = "Токены", Text = usageHint, Cls = "meta" });
                }

                RecordTokenUsage(prefs, text, reply);
                StatusText = "Ответ внешней модели получен.";
                PendingChatAttachments.Clear();
                return;
            }

            // Roza server
            if (UseWebSocket)
            {
                if (_socket is not { IsConnected: true })
                {
                    await ConnectAsync().ConfigureAwait(true);
                    if (_socket is not { IsConnected: true })
                    {
                        AppendChatLine(new ChatLineVm { Role = "Ошибка", Text = "Нет WebSocket. Проверьте сервер и нажмите «Подключить»." });
                        return;
                    }
                }

                var wsAtt = attachmentDtos.Count > 0 ? attachmentDtos : null;
                await _socket
                    .SendMessageAsync(SessionId.Trim(), text, AgentMode, ContextKey.Trim(), wsAtt, CancellationToken.None)
                    .ConfigureAwait(true);
                PendingChatAttachments.Clear();
            }
            else
            {
                StatusText = "Запрос…";
                IReadOnlyList<ChatAttachmentDto>? att = attachmentDtos.Count > 0 ? attachmentDtos : null;
                var authTok = CompanionLocalSettingsStore.Load().AuthToken;
                var dto = await _http
                    .ChatPostDetailedAsync(baseUri, text, AgentMode, SessionId, ContextKey.Trim(), att, authTok, CancellationToken.None)
                    .ConfigureAwait(true);
                var reply = dto.Reply ?? "";
                AppendChatLine(new ChatLineVm { Role = "Roza AI", Text = reply });
                var u = FormatJsonUsage(dto.Usage);
                if (!string.IsNullOrWhiteSpace(u))
                {
                    LastTokenUsageText = "Roza AI: " + u;
                    AppendChatLine(new ChatLineVm { Role = "Токены", Text = u, Cls = "meta" });
                }

                RecordTokenUsage(prefs, text, reply);
                StatusText = "Ответ получен (HTTP).";
                PendingChatAttachments.Clear();
            }
        }
        catch (Exception ex)
        {
            AppendChatLine(new ChatLineVm { Role = "Ошибка", Text = ex.Message });
            StatusText = ex.Message;
        }
        finally
        {
            IsBusy = false;
            RefreshQuotaUi();
        }
    }

    [RelayCommand]
    private async Task ResetChatAsync()
    {
        if (_socket is { IsConnected: true })
            await _socket.ResetAsync(SessionId.Trim(), CancellationToken.None).ConfigureAwait(true);

        SessionId = NewSessionId();
        ChatLines.Clear();
        PendingChatAttachments.Clear();
        LastTokenUsageText = "";
        if (SelectedSession is not null)
        {
            _sessionLogs[SelectedSession.Id] = new List<ChatLineVm>();
            SelectedSession.TouchNow();
        }

        StatusText = "Чат сброшен.";
        PersistSessions();
    }

    [RelayCommand]
    private async Task PushIntegrationAsync()
    {
        var md = IntegrationMarkdown.Trim();
        if (string.IsNullOrEmpty(md))
        {
            StatusText = "Вставьте markdown для передачи в Roza.";
            return;
        }

        var baseUri = RozaEndpoints.HttpBase(ServerUrl);
        IsBusy = true;
        try
        {
            var token = string.IsNullOrWhiteSpace(IntegrationToken) ? null : IntegrationToken.Trim();
            await _http.PushIntegrationAsync(baseUri, ContextKey.Trim(), md, token, CancellationToken.None)
                .ConfigureAwait(true);
            StatusText = $"Контекст записан (ключ «{ContextKey.Trim()}»). Следующее сообщение в чате подставит его.";
        }
        catch (Exception ex)
        {
            StatusText = "Интеграция: " + ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private async Task RefreshTrainingCatalogAsync()
    {
        var baseUri = RozaEndpoints.HttpBase(ServerUrl);
        IsBusy = true;
        try
        {
            if (!await _http.HealthOkAsync(baseUri, CancellationToken.None).ConfigureAwait(true))
            {
                TrainingDatasetsText = "Сервер недоступен.";
                TrainingSkillsText = "";
                LearningAnalyticsText = "Сервер недоступен.";
                LearningLedBrush = LearningOffBrush;
                LearningLedCaption = "журнал: нет связи";
                StatusText = "Сначала подключитесь к серверу Roza.";
                return;
            }

            var ds = await _http.TryGetStudioDatasetsAsync(baseUri, CancellationToken.None).ConfigureAwait(true);
            TrainingDatasetsText = FormatStudioDatasets(ds);

            var sk = await _http.TryGetStudioSkillsJsonAsync(baseUri, CancellationToken.None).ConfigureAwait(true);
            TrainingSkillsText = string.IsNullOrWhiteSpace(sk)
                ? "Пустой ответ /api/studio/skills."
                : PrettyFormatJson(sk);

            await RefreshLearningStatsAsync(baseUri).ConfigureAwait(true);

            StatusText = "База обучения: каталог обновлён.";
        }
        catch (Exception ex)
        {
            TrainingDatasetsText = "Ошибка: " + ex.Message;
            TrainingSkillsText = "";
            StatusText = ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private void StartRozaWeb()
    {
        StartRozaProcess("web");
    }

    [RelayCommand]
    private void StartRozaDesktop()
    {
        StartRozaProcess("desktop");
    }

    private void StartRozaProcess(string mode)
    {
        var dir = RozaProjectPath.Trim();
        if (string.IsNullOrEmpty(dir) || !Directory.Exists(dir))
        {
            StatusText = "Укажите существующий каталог с проектом Roza (где лежит pyproject.toml).";
            return;
        }

        try
        {
            Process.Start(new ProcessStartInfo
            {
                FileName = "python",
                ArgumentList = { "-m", "roza", mode },
                WorkingDirectory = dir,
                UseShellExecute = false,
            });
            StatusText = $"Запущен процесс: python -m roza {mode}";
        }
        catch (Exception ex)
        {
            StatusText = "Не удалось запустить: " + ex.Message;
        }
    }

    [RelayCommand]
    private void OpenStudio()
    {
        try
        {
            var baseUri = RozaEndpoints.HttpBase(ServerUrl);
            var u = new Uri(baseUri, "studio");
            Process.Start(new ProcessStartInfo { FileName = u.ToString(), UseShellExecute = true });
        }
        catch (Exception ex)
        {
            StatusText = "Studio: " + ex.Message;
        }
    }

    [RelayCommand]
    private void OpenDashboardFolder()
    {
        var p = DashboardPath.Trim();
        if (string.IsNullOrEmpty(p) || !Directory.Exists(p))
        {
            StatusText = "Укажите каталог с фронтендом (например …/frontend).";
            return;
        }

        Process.Start(new ProcessStartInfo
        {
            FileName = p,
            UseShellExecute = true,
        });
    }

    private async Task PullInsightsFromServerAsync(Uri baseUri)
    {
        try
        {
            var health = await _http.TryGetHealthSummaryAsync(baseUri, CancellationToken.None).ConfigureAwait(true);
            HealthDetailText = health ?? "Пустой ответ /api/health.";

            var raw = await _http.TryGetHealthRawAsync(baseUri, CancellationToken.None).ConfigureAwait(true);
            UpdateLlmPresetHintFromHealthRaw(raw);

            var ui = await _http.TryGetUiConfigAsync(baseUri, CancellationToken.None).ConfigureAwait(true);
            BrainModesText = FormatBrainModes(ui);

            var ws = await _http.TryGetWorkspaceAsync(baseUri, CancellationToken.None).ConfigureAwait(true);
            WorkspaceInsightText = FormatWorkspace(ws);
        }
        catch
        {
            HealthDetailText = "Не удалось прочитать /api/health или смежные API.";
        }
    }

    private void UpdateLlmPresetHintFromHealthRaw(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw))
        {
            LlmPresetHint =
                "Переключение: POST /api/llm/preset (только hf_local). Пресеты задаются в config.yaml (preset_light / preset_strong).";
            return;
        }

        try
        {
            using var doc = JsonDocument.Parse(raw);
            var root = doc.RootElement;
            var backend = root.TryGetProperty("llm_backend", out var lb) ? lb.GetString() : null;
            if (backend != "hf_local")
            {
                LlmPresetHint =
                    $"Текущий бэкенд: {backend ?? "?"}. Пресеты light/strong применимы только к hf_local.";
                return;
            }

            var mid = root.TryGetProperty("model_id", out var m) && m.ValueKind == JsonValueKind.String ? m.GetString() : "?";
            var pl = root.TryGetProperty("preset_light", out var pls) && pls.ValueKind == JsonValueKind.String ? pls.GetString() : "";
            var ps = root.TryGetProperty("preset_strong", out var pss) && pss.ValueKind == JsonValueKind.String ? pss.GetString() : "";
            LlmPresetHint =
                $"Сейчас в ответе health: model_id «{mid}». Лёгкая: «{pl}». Усиленная: «{ps}». Кнопки шлют POST /api/llm/preset.";
        }
        catch
        {
            LlmPresetHint = "Не удалось разобрать JSON /api/health для подсказки пресетов.";
        }
    }

    private async Task RefreshLearningStatsAsync(Uri baseUri)
    {
        if (!await _http.HealthOkAsync(baseUri, CancellationToken.None).ConfigureAwait(true))
        {
            LearningAnalyticsText = "Сервер недоступен.";
            LearningLedBrush = LearningOffBrush;
            LearningLedCaption = "журнал: нет связи";
            return;
        }

        var st = await _http.TryGetLearningStatsAsync(baseUri, CancellationToken.None).ConfigureAwait(true);
        LearningAnalyticsText = FormatLearningStats(st);
        ApplyLearningIndicator(st);
        _suppressLearningSync = true;
        LearningRecordingEnabled = st?.Enabled ?? false;
        _suppressLearningSync = false;
    }

    private void ApplyLearningIndicator(LearningStatsDto? d)
    {
        if (d is null)
        {
            LearningLedBrush = LearningOffBrush;
            LearningLedCaption = "журнал: нет данных";
            return;
        }

        LearningLedBrush = d.Enabled ? LearningOnBrush : LearningOffBrush;
        var cfg = d.PersistedInConfig ? "в config вкл" : "в config выкл";
        LearningLedCaption = d.Enabled ? $"запись вкл ({cfg})" : $"запись выкл ({cfg})";
    }

    private static string FormatLearningStats(LearningStatsDto? d)
    {
        if (d is null)
            return "Нет ответа GET /api/learning/stats.";
        var kb = d.Bytes / 1024.0;
        return string.Join(
            Environment.NewLine,
            $"Журнал: {(d.Enabled ? "запись включена" : "запись выключена")} (эффективно для процесса)",
            $"В config.yaml learning_enabled: {(d.PersistedInConfig ? "да" : "нет")}",
            $"Строк в логе: {d.Lines}   размер: ≈{kb:0.#} КБ",
            d.LogPath);
    }

    [RelayCommand]
    private async Task ApplyLlmPresetLightAsync()
    {
        await ApplyLlmPresetCoreAsync("light").ConfigureAwait(true);
    }

    [RelayCommand]
    private async Task ApplyLlmPresetStrongAsync()
    {
        await ApplyLlmPresetCoreAsync("strong").ConfigureAwait(true);
    }

    [RelayCommand]
    private async Task ApplyLlmPresetDefaultAsync()
    {
        await ApplyLlmPresetCoreAsync("default").ConfigureAwait(true);
    }

    private async Task ApplyLlmPresetCoreAsync(string preset)
    {
        var baseUri = RozaEndpoints.HttpBase(ServerUrl);
        IsBusy = true;
        try
        {
            if (!await _http.HealthOkAsync(baseUri, CancellationToken.None).ConfigureAwait(true))
            {
                StatusText = "Сервер недоступен.";
                return;
            }

            var ok = await _http.PostLlmPresetAsync(baseUri, preset, CancellationToken.None).ConfigureAwait(true);
            if (!ok)
            {
                StatusText = "POST /api/llm/preset не принят (нужен hf_local и корректный preset).";
                return;
            }

            await PullInsightsFromServerAsync(baseUri).ConfigureAwait(true);
            StatusText = $"Пресет модели: {preset}.";
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private async Task UploadTrainingDatasetAsync()
    {
        var baseUri = RozaEndpoints.HttpBase(ServerUrl);
        if (!await _http.HealthOkAsync(baseUri, CancellationToken.None).ConfigureAwait(true))
        {
            StatusText = "Сервер недоступен — загрузка невозможна.";
            return;
        }

        if (Application.Current?.ApplicationLifetime is not IClassicDesktopStyleApplicationLifetime life
            || life.MainWindow is not { } owner)
        {
            StatusText = "Не удалось открыть диалог выбора файла.";
            return;
        }

        var top = TopLevel.GetTopLevel(owner);
        if (top is null)
        {
            StatusText = "Не удалось открыть диалог выбора файла.";
            return;
        }

        IsBusy = true;
        try
        {
            var picked = await top.StorageProvider.OpenFilePickerAsync(
                    new FilePickerOpenOptions
                    {
                        Title = "Датасет для каталога Studio",
                        AllowMultiple = false,
                        FileTypeFilter = new List<FilePickerFileType>
                        {
                            new("Датасеты")
                            {
                                Patterns = new[] { "*.jsonl", "*.json", "*.txt", "*.yaml", "*.yml" },
                            },
                            FilePickerFileTypes.All,
                        },
                    })
                .ConfigureAwait(true);

            if (picked is not { Count: > 0 })
            {
                StatusText = "Загрузка отменена.";
                return;
            }

            var file = picked[0];
            await using var stream = await file.OpenReadAsync().ConfigureAwait(true);
            var name = file.Name;
            var resp = await _http.UploadStudioDatasetAsync(baseUri, stream, name, CancellationToken.None).ConfigureAwait(true);
            if (string.IsNullOrEmpty(resp))
            {
                StatusText = "Загрузка не удалась (проверьте тип файла и размер).";
                return;
            }

            StatusText = "Файл отправлен на сервер.";
            await RefreshTrainingCatalogAsync().ConfigureAwait(true);
        }
        catch (Exception ex)
        {
            StatusText = "Загрузка: " + ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    private static string FormatBrainModes(UiConfigDto? ui)
    {
        if (ui is null)
            return "Нет данных /api/ui-config.";
        var sb = new StringBuilder();
        if (!string.IsNullOrWhiteSpace(ui.AssistantName))
            sb.AppendLine("Ассистент: " + ui.AssistantName.Trim());
        sb.AppendLine("think_first: " + (ui.AssistantThinkFirst ? "да" : "нет"));
        sb.AppendLine("swarm_prompt: " + (ui.AssistantSwarmPrompt ? "да" : "нет"));
        if (!string.IsNullOrWhiteSpace(ui.TtsProvider))
            sb.AppendLine("TTS: " + ui.TtsProvider);
        return sb.ToString().TrimEnd();
    }

    private static string FormatWorkspace(WorkspaceApiDto? ws)
    {
        if (ws is null)
            return "Нет данных /api/workspace.";
        if (ws.Roots.Count == 0)
            return (ws.Hint ?? "Корни workspace пусты (задайте workspace.roots в config.yaml).").Trim();
        return string.Join(Environment.NewLine, ws.Roots.Select(r => "• " + r));
    }

    private static string FormatStudioDatasets(StudioDatasetsResponseDto? ds)
    {
        if (ds is null)
            return "Нет ответа от /api/studio/datasets (проверьте версию Roza).";
        if (ds.Files.Count == 0)
            return $"Каталог датасетов пуст.\n{ds.Dir}";
        var lines = new List<string> { $"Каталог: {ds.Dir}", "" };
        foreach (var f in ds.Files.OrderBy(x => x.Name))
        {
            var kb = f.Size / 1024.0;
            lines.Add($"• {f.Name}  ({kb:0.#} КБ)");
        }

        return string.Join(Environment.NewLine, lines);
    }

    private static string PrettyFormatJson(string raw)
    {
        try
        {
            using var doc = JsonDocument.Parse(raw);
            return JsonSerializer.Serialize(
                doc.RootElement,
                new JsonSerializerOptions { WriteIndented = true, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping });
        }
        catch
        {
            return raw;
        }
    }

    private void OnSocketThinking()
    {
        StatusText = "Roza думает…";
    }

    private void OnSocketReply(string text, string? usageJson)
    {
        AppendChatLine(new ChatLineVm { Role = "Roza", Text = text });
        if (!string.IsNullOrWhiteSpace(usageJson))
        {
            try
            {
                using var doc = JsonDocument.Parse(usageJson);
                var u = FormatJsonUsage(doc.RootElement);
                if (!string.IsNullOrWhiteSpace(u))
                {
                    LastTokenUsageText = "Roza: " + u;
                    AppendChatLine(new ChatLineVm { Role = "Токены", Text = u, Cls = "meta" });
                }
            }
            catch
            {
                // ignore malformed usage
            }
        }

        StatusText = "Готово.";
    }

    private void OnSocketError(string msg)
    {
        AppendChatLine(new ChatLineVm { Role = "Ошибка", Text = msg });
        StatusText = msg;
    }

    private void OnSocketDisconnected()
    {
        SocketConnected = false;
        StatusText = "WebSocket разорван. Нажмите «Подключить» снова.";
        RefreshConnectionSummary();
    }

    private async Task DisconnectSocketAsync()
    {
        if (_socket is not null)
        {
            _socket.Thinking -= OnSocketThinking;
            _socket.Reply -= OnSocketReply;
            _socket.Error -= OnSocketError;
            _socket.Disconnected -= OnSocketDisconnected;
            await _socket.DisposeAsync().ConfigureAwait(false);
            _socket = null;
        }

        _socketCts?.Cancel();
        _socketCts?.Dispose();
        _socketCts = null;
    }

    private void AppendChatLine(ChatLineVm line)
    {
        ChatLines.Add(line);
        if (SelectedSession is null)
            return;

        if (line.Role == "Вы" && SelectedSession.Title == "Новый чат")
        {
            var t = line.Text.ReplaceLineEndings(" ").Trim();
            if (t.Length > 42)
                t = t[..39] + "…";
            SelectedSession.Title = string.IsNullOrEmpty(t) ? "Новый чат" : t;
        }

        SelectedSession.TouchNow();
        SyncCurrentChatToLog();
        PersistSessions();
    }

    private void SyncCurrentChatToLog()
    {
        if (string.IsNullOrEmpty(_currentSessionId))
            return;

        if (!_sessionLogs.TryGetValue(_currentSessionId, out var list))
        {
            list = new List<ChatLineVm>();
            _sessionLogs[_currentSessionId] = list;
        }

        list.Clear();
        foreach (var line in ChatLines)
            list.Add(line);
    }

    private void PersistSessions()
    {
        try
        {
            SyncCurrentChatToLog();
            ChatSessionStore.Save(SelectedSession?.Id, Sessions.ToList(), _sessionLogs);
        }
        catch
        {
            // ignore disk errors
        }
    }

    private void SaveLocalPrefs()
    {
        if (_prefsHydrating)
            return;
        try
        {
            var cur = CompanionLocalSettingsStore.Load();
            cur.ServerUrl = ServerUrl.Trim();
            cur.ExternalOpenAiBaseUrl = ExternalOpenAiBaseUrl.Trim();
            cur.ExternalOpenAiApiKey = ExternalOpenAiApiKey;
            cur.ExternalOpenAiModel = ExternalOpenAiModel.Trim();
            cur.ChatTargetIndex = ChatTargetIndex;
            cur.YandexClientId = YandexClientId.Trim();
            cur.YandexClientSecret = YandexClientSecret;
            cur.UiTheme = UiThemeIndex;
            CompanionLocalSettingsStore.Save(cur);
        }
        catch
        {
            // ignore
        }
    }

    private static string FormatOutgoingUserBubble(string text, List<ChatAttachmentDto> att)
    {
        if (att.Count == 0)
            return text;
        var names = string.Join(", ", att.Select(a => string.IsNullOrWhiteSpace(a.Filename) ? "файл" : a.Filename));
        return text + "\n\n[вложения: " + names + "]";
    }

    private static string MergeAttachmentsForProvider(string text, List<ChatAttachmentDto> att)
    {
        if (att.Count == 0)
            return text;
        var parts = new List<string>();
        foreach (var a in att)
        {
            var fn = string.IsNullOrWhiteSpace(a.Filename) ? "файл" : a.Filename.Trim();
            var c = (a.Content ?? "").Trim();
            if (string.IsNullOrEmpty(c))
                continue;
            parts.Add($"### Вложение: {fn}\n```\n{c}\n```");
        }

        if (parts.Count == 0)
            return text;
        return string.Join("\n\n", parts) + "\n\n---\n**Запрос пользователя:**\n" + text;
    }

    private static string FormatJsonUsage(JsonElement el)
    {
        if (el.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null)
            return "";
        if (el.ValueKind == JsonValueKind.Object)
        {
            int? pi = el.TryGetProperty("prompt_tokens", out var p) && p.TryGetInt32(out var pv) ? pv : null;
            int? ci = el.TryGetProperty("completion_tokens", out var c) && c.TryGetInt32(out var cv) ? cv : null;
            int? ti = el.TryGetProperty("total_tokens", out var t) && t.TryGetInt32(out var tv) ? tv : null;
            if (pi is not null || ci is not null || ti is not null)
                return $"prompt {pi ?? 0} · completion {ci ?? 0} · всего {ti ?? 0}";
            return el.GetRawText();
        }

        return el.ValueKind == JsonValueKind.String ? (el.GetString() ?? "") : el.GetRawText();
    }

    [RelayCommand]
    private async Task CopyChatLineAsync(string? text)
    {
        if (string.IsNullOrEmpty(text))
            return;
        if (Application.Current?.ApplicationLifetime is not IClassicDesktopStyleApplicationLifetime { MainWindow: { } w })
            return;
        var top = TopLevel.GetTopLevel(w);
        if (top?.Clipboard is null)
            return;
        await top.Clipboard.SetTextAsync(text).ConfigureAwait(true);
        StatusText = "Текст сообщения скопирован.";
    }

    [RelayCommand]
    private async Task DeleteSessionAsync(SessionEntryVm? victim)
    {
        victim ??= SelectedSession;
        if (victim is null || Sessions.Count <= 1)
        {
            StatusText = "Нужен хотя бы один чат.";
            return;
        }

        var wasSelected = SelectedSession?.Id == victim.Id;
        if (wasSelected)
            SyncCurrentChatToLog();
        _sessionLogs.Remove(victim.Id);
        Sessions.Remove(victim);

        if (wasSelected)
        {
            await DisconnectSocketAsync().ConfigureAwait(true);
            SocketConnected = false;
            _suppressSelectedSessionHandler = true;
            SelectedSession = Sessions[0];
            _suppressSelectedSessionHandler = false;
            await ApplySessionChangeAsync(SelectedSession).ConfigureAwait(true);
        }
        else
        {
            PersistSessions();
        }

        StatusText = "Чат удалён.";
    }

    [RelayCommand]
    private void NavChat() => ShellSection = 0;

    [RelayCommand]
    private void NavStudio() => ShellSection = 1;

    [RelayCommand]
    private void NavSettings() => ShellSection = 2;

    [RelayCommand]
    private void NavFiles() => ShellSection = 3;

    public void NotifyWindowReadyTheme() => RaiseApplyTheme();

    private void RaiseApplyTheme()
    {
        if (!_initVmDone)
            return;
        ApplyThemeRequested?.Invoke(ResolveEffectiveLight());
    }

    private bool ResolveEffectiveLight() =>
        UiThemeIndex switch
        {
            1 => true,
            0 => false,
            _ => Application.Current?.ActualThemeVariant == ThemeVariant.Light,
        };

    partial void OnUiThemeIndexChanged(int value)
    {
        if (_prefsHydrating || !_initVmDone)
            return;
        SaveLocalPrefs();
        RaiseApplyTheme();
    }

    private void SeedLearningTracks()
    {
        LearningTracks.Clear();
        LearningTracks.Add(
            new LearningTrackVm(
                "Сервер Roza",
                "Чат и агент в вашем окружении",
                "История сообщений хранится на сервере по session_id — WebSocket и HTTP используют одни и те же сессии."));
        LearningTracks.Add(
            new LearningTrackVm(
                "Внешний OpenAI-совместимый API",
                "Gemini, OpenRouter, LM Studio…",
                "Ключ и endpoint задаются в настройках; запросы идут напрямую к провайдеру, минуя сервер Roza."));
        LearningTracks.Add(
            new LearningTrackVm(
                "Агент и workspace",
                "Инструменты из components.yaml",
                "Режим «Агент» на сервере использует whitelist команд и файлы в пределах workspace из config.yaml."));
        LearningTracks.Add(
            new LearningTrackVm(
                "HF локально и пресеты",
                "Только при llm_backend: hf_local",
                "Кнопки «Лёгкая / Усиленная» вызывают POST /api/llm/preset — см. подсказку выше после опроса /api/health."));
    }

    private void RefreshSessionContextLine()
    {
        var sess = SelectedSession?.Title?.Trim();
        if (string.IsNullOrEmpty(sess))
            sess = "Новый сеанс";
        var repo = string.IsNullOrEmpty(LastRepoFolderLabel)
            ? "репозиторий не прикреплён"
            : $"папка «{LastRepoFolderLabel}»";
        string model;
        if (ChatTargetIndex == 0)
            model = AgentMode ? "Roza AI · агент" : "Roza AI";
        else
        {
            var ext = string.IsNullOrWhiteSpace(ExternalOpenAiModel) ? "внешний API" : ExternalOpenAiModel.Trim();
            model = $"внешняя · {ext}";
        }

        SessionContextLine = $"{sess} · {repo} · {model}";
    }

    private static bool IsProPlan(CompanionLocalPrefs prefs) =>
        string.Equals(prefs.SubscriptionPlan, "pro", StringComparison.OrdinalIgnoreCase);

    private void RefreshQuotaUi()
    {
        var prefs = CompanionLocalSettingsStore.Load();
        TokenQuotaLine = TokenQuotaService.QuotaLabel(prefs);
        ExternalApiUnlocked = IsProPlan(prefs);
        AuthLoginLine = string.IsNullOrWhiteSpace(prefs.AuthLogin)
            ? ""
            : "Аккаунт: " + prefs.AuthLogin.Trim();
        if (!string.IsNullOrWhiteSpace(prefs.AuthToken))
            _ = SyncQuotaFromServerAsync();
    }

    private async Task SyncQuotaFromServerAsync()
    {
        try
        {
            var prefs = CompanionLocalSettingsStore.Load();
            await RozaPlatformApi.SyncPrefsFromServerAsync(prefs).ConfigureAwait(true);
            var updated = CompanionLocalSettingsStore.Load();
            TokenQuotaLine = TokenQuotaService.QuotaLabel(updated);
            ExternalApiUnlocked = IsProPlan(updated);
            if (updated.ChatTargetIndex == 1 && !IsProPlan(updated))
            {
                _prefsHydrating = true;
                ChatTargetIndex = 0;
                _prefsHydrating = false;
            }
        }
        catch
        {
            // ignore — локальная квота остаётся запасной
        }
    }

    private void RecordTokenUsage(CompanionLocalPrefs prefs, string userText, string reply)
    {
        TokenQuotaService.RecordUsage(prefs, TokenQuotaService.EstimateTokens(userText, reply));
        CompanionLocalSettingsStore.Save(prefs);
    }

    private static string NewSessionId() => Guid.NewGuid().ToString("N")[..12];

    private static long NowMs() => DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
}
