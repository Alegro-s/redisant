using Avalonia;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Data.Core;
using Avalonia.Data.Core.Plugins;
using System.Linq;
using Avalonia.Markup.Xaml;
using RozaCompanion.Services;
using RozaCompanion.ViewModels;
using RozaCompanion.Views;

namespace RozaCompanion;

public partial class App : Application
{
    public override void Initialize()
    {
        AvaloniaXamlLoader.Load(this);
    }

    public override void OnFrameworkInitializationCompleted()
    {
        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            var prefs = CompanionLocalSettingsStore.Load();
            if (string.IsNullOrWhiteSpace(prefs.AuthToken))
            {
                var gateVm = new AuthGateViewModel();
                var gate = new AuthGateWindow { DataContext = gateVm };
                gateVm.SignedIn += () =>
                {
                    desktop.MainWindow = new MainWindow { DataContext = new MainWindowViewModel() };
                    desktop.MainWindow.Show();
                    gate.Close();
                };
                desktop.MainWindow = gate;
            }
            else
            {
                desktop.MainWindow = new MainWindow { DataContext = new MainWindowViewModel() };
            }
        }

        base.OnFrameworkInitializationCompleted();
    }
}