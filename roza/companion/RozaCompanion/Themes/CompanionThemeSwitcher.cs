using System;
using Avalonia.Controls;
using Avalonia.Markup.Xaml;
using Avalonia.Styling;

namespace RozaCompanion.Themes;

public static class CompanionThemeSwitcher
{
    /// <summary>Roza AI — тёмная палитра.</summary>
    private static readonly Uri DarkUri = new("avares://RozaCompanion/Themes/GeminiDark.axaml");

    /// <summary>Roza Studio — светлая палитра.</summary>
    private static readonly Uri LightUri = new("avares://RozaCompanion/Themes/GeminiLight.axaml");

    public static void Apply(Window window, bool useLight)
    {
        if (window.Resources is not ResourceDictionary rd)
            return;

        rd.MergedDictionaries.Clear();
        var uri = useLight ? LightUri : DarkUri;
        var dict = (ResourceDictionary)AvaloniaXamlLoader.Load(uri);
        rd.MergedDictionaries.Add(dict);
    }

    public static void ApplyApplicationChrome(int themeMode, bool effectiveLight)
    {
        if (Avalonia.Application.Current is null)
            return;
        Avalonia.Application.Current.RequestedThemeVariant = themeMode == 2
            ? ThemeVariant.Default
            : (effectiveLight ? ThemeVariant.Light : ThemeVariant.Dark);
    }
}
