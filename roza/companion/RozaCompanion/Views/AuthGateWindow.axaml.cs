using Avalonia.Controls;
using Avalonia.Markup.Xaml;

namespace RozaCompanion.Views;

public partial class AuthGateWindow : Window
{
    public AuthGateWindow()
    {
        InitializeComponent();
    }

    private void InitializeComponent() => AvaloniaXamlLoader.Load(this);
}
