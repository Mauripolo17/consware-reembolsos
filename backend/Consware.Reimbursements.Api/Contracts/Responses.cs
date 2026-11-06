namespace Consware.Reimbursements.Api.Contracts;

public static class Responses
{
    public static ApiResponse<T> Ok<T>(HttpContext context, T data) =>
        new(true, "Operación completada.", data, [], context.TraceIdentifier);

    public static ApiResponse<object> Fail(HttpContext context, params ApiError[] errors) =>
        new(false, "No se pudo completar la solicitud.", null, errors, context.TraceIdentifier);
}
