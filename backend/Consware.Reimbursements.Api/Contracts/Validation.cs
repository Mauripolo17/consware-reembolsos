using System.Globalization;
using System.Numerics;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace Consware.Reimbursements.Api.Contracts;

public static class Validation
{
    public static void Text(List<ApiError> errors, string? value, string field, int max)
    {
        if (string.IsNullOrWhiteSpace(value))
        {
            errors.Add(new(field, "REQUIRED", "Este campo es obligatorio."));
        }
        else if (value.Trim().Length > max)
        {
            errors.Add(new(field, "MAX_LENGTH_EXCEEDED", $"Este campo admite hasta {max} caracteres."));
        }
    }

    public static decimal Amount(JsonElement value, List<ApiError> errors)
    {
        if (value.ValueKind is JsonValueKind.Undefined or JsonValueKind.Null)
        {
            errors.Add(new("amount", "REQUIRED", "El monto es obligatorio."));
            return 0;
        }

        if (value.ValueKind != JsonValueKind.Number)
        {
            errors.Add(new("amount", "INVALID_REQUEST", "El monto debe ser numérico."));
            return 0;
        }

        var raw = value.GetRawText();
        var parts = Regex.Match(raw, @"^-?(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$");
        var fraction = parts.Groups[2].Value;
        var digits = parts.Groups[1].Value + fraction;
        var exponent = parts.Groups[3].Success
            ? BigInteger.Parse(parts.Groups[3].Value, CultureInfo.InvariantCulture)
            : BigInteger.Zero;
        var scale = fraction.Length - exponent - (digits.Length - digits.TrimEnd('0').Length);

        if (digits.Trim('0').Length > 0 && scale > 2)
        {
            errors.Add(new("amount", "INVALID_AMOUNT_PRECISION", "El monto admite hasta dos decimales."));
            return 0;
        }

        if (!value.TryGetDecimal(out var amount)
            || amount > 9999999999999999.99m
            || amount < -9999999999999999.99m)
        {
            errors.Add(new("amount", "AMOUNT_OUT_OF_RANGE", "El monto excede el rango permitido."));
        }
        else if (amount <= 0)
        {
            errors.Add(new("amount", "POSITIVE_AMOUNT_REQUIRED", "El monto debe ser mayor a cero."));
        }
        else if (decimal.Round(amount, 2) != amount)
        {
            errors.Add(new("amount", "INVALID_AMOUNT_PRECISION", "El monto admite hasta dos decimales."));
        }

        return amount;
    }
}
