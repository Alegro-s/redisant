using System;
using System.Diagnostics;
using System.Threading.Tasks;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RozaCompanion.Services;

namespace RozaCompanion.ViewModels;

public partial class AuthGateViewModel : ViewModelBase
{
    [ObservableProperty] private string _login = "";

    [ObservableProperty] private string _password = "";

    [ObservableProperty] private string _errorText = "";

    [ObservableProperty] private bool _isBusy;

    [ObservableProperty]
    private string _statusHint =
        "Вход нужен для подписки и синхронизации с облаком. "
        + "Для кода и проектов на этом компьютере можно начать без аккаунта — кнопка ниже.";

    public event Action? SignedIn;

    [RelayCommand]
    private async Task SignInAsync()
    {
        ErrorText = "";
        if (string.IsNullOrWhiteSpace(Login) || string.IsNullOrEmpty(Password))
        {
            ErrorText = "Введите email (или логин) и пароль.";
            return;
        }

        IsBusy = true;
        try
        {
            var prefs = CompanionLocalSettingsStore.Load();
            var (ok, token, savedLogin, err) = await RozaAuthApi
                .LoginAsync(prefs.AuthApiUrl, Login, Password)
                .ConfigureAwait(true);
            if (!ok)
            {
                ErrorText = string.IsNullOrWhiteSpace(err) ? "Не удалось войти." : err;
                return;
            }

            prefs.AuthToken = token;
            prefs.AuthLogin = savedLogin;
            prefs.LocalOnlyMode = false;
            CompanionLocalSettingsStore.Save(prefs);
            await RozaPlatformApi.SyncPrefsFromServerAsync(prefs).ConfigureAwait(true);
            SignedIn?.Invoke();
        }
        catch (Exception ex)
        {
            ErrorText = ex.Message;
        }
        finally
        {
            IsBusy = false;
        }
    }

    [RelayCommand]
    private void ContinueLocal()
    {
        ErrorText = "";
        var prefs = CompanionLocalSettingsStore.Load();
        prefs.LocalOnlyMode = true;
        prefs.AuthToken = "";
        prefs.AuthLogin = "";
        if (prefs.ServerUrl.Contains("waypointclub.ru", StringComparison.OrdinalIgnoreCase))
            prefs.ServerUrl = "http://127.0.0.1:8765";
        CompanionLocalSettingsStore.Save(prefs);
        SignedIn?.Invoke();
    }

    [RelayCommand]
    private void OpenRegisterInBrowser()
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
            ErrorText = "Не удалось открыть браузер: " + ex.Message;
        }
    }
}
