using System;
using System.Globalization;
using Avalonia.Data.Converters;
using Avalonia.Media;

namespace RozaCompanion.Converters;

/// <summary>Цвет левой полоски у пузыря сообщения (как мягкий акцент iOS).</summary>
public sealed class RoleAccentConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        var s = value?.ToString() ?? "";
        var color = s switch
        {
            "Вы" => Color.Parse("#0A84FF"),
            "Roza" => Color.Parse("#34C759"),
            "Ошибка" => Color.Parse("#FF453A"),
            "Система" => Color.Parse("#FF9F0A"),
            _ => Color.Parse("#C7C7CC"),
        };
        return new SolidColorBrush(color);
    }

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}
