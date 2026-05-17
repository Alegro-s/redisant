using System;
using System.Globalization;
using Avalonia.Data.Converters;

namespace RozaCompanion.Converters;

public sealed class BoolToDaNetConverter : IValueConverter
{
    public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        value is true ? "да" : "нет";

    public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture) =>
        throw new NotSupportedException();
}
