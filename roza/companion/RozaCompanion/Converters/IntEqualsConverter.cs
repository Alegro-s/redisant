using System;
using System.Globalization;
using Avalonia.Data.Converters;

namespace RozaCompanion.Converters;

public sealed class IntEqualsConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        if (value is not int i)
            return false;
        var p = parameter switch
        {
            int n => n,
            long l => (int)l,
            string s when int.TryParse(s, NumberStyles.Integer, culture, out var x) => x,
            _ => int.TryParse(parameter?.ToString(), NumberStyles.Integer, culture, out var y) ? y : int.MinValue,
        };
        return p != int.MinValue && i == p;
    }

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}
