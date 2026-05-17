using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Styling;
using RozaCompanion.Themes;
using RozaCompanion.ViewModels;

namespace RozaCompanion.Views;

public partial class MainWindow : Window
{
    private TextBox? _chatInput;

    public MainWindow()
    {
        InitializeComponent();
        Loaded += OnLoaded;
        Unloaded += OnUnloaded;
        if (Avalonia.Application.Current is not null)
            Avalonia.Application.Current.ActualThemeVariantChanged += OnSystemThemeChanged;
    }

    private void OnUnloaded(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm)
            vm.ApplyThemeRequested -= OnApplyThemeRequested;
        if (_chatInput is not null)
        {
            _chatInput.KeyDown -= OnChatInputKeyDown;
            _chatInput = null;
        }
        if (Avalonia.Application.Current is not null)
            Avalonia.Application.Current.ActualThemeVariantChanged -= OnSystemThemeChanged;
    }

    private void OnSystemThemeChanged(object? sender, System.EventArgs e)
    {
        if (DataContext is MainWindowViewModel vm && vm.UiThemeIndex == 2)
            vm.NotifyWindowReadyTheme();
    }

    private void OnLoaded(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm)
        {
            vm.ApplyThemeRequested += OnApplyThemeRequested;
            vm.NotifyWindowReadyTheme();
        }

        _chatInput = this.FindControl<TextBox>("ChatInputBox");
        if (_chatInput is not null)
            _chatInput.KeyDown += OnChatInputKeyDown;
    }

    private void OnChatInputKeyDown(object? sender, KeyEventArgs e)
    {
        if (e.Key != Key.Enter || (e.KeyModifiers & KeyModifiers.Shift) != 0)
            return;
        if (DataContext is not MainWindowViewModel vm)
            return;
        if (vm.IsBusy)
            return;
        e.Handled = true;
        vm.SendCommand.Execute(null);
    }

    private void OnApplyThemeRequested(bool useLight)
    {
        CompanionThemeSwitcher.Apply(this, useLight);
        if (DataContext is MainWindowViewModel vm)
            CompanionThemeSwitcher.ApplyApplicationChrome(vm.UiThemeIndex, useLight);
    }
}
