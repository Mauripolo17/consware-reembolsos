using Consware.Reimbursements.Api.Contracts;
using Consware.Reimbursements.Api.Exceptions;

namespace Consware.Reimbursements.Api.Middleware;

public sealed class ApiExceptionMiddleware(
    RequestDelegate next,
    ILogger<ApiExceptionMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (Exception exception) when (
            !context.Response.HasStarted
            && !(exception is OperationCanceledException && context.RequestAborted.IsCancellationRequested))
        {
            var (statusCode, errors) = exception switch
            {
                RequestValidationException validation => (400, validation.Errors),
                ReimbursementNotFoundException => (404, new[]
                {
                    new ApiError(null, "NOT_FOUND", "No se encontró la solicitud.")
                }),
                ReimbursementStateConflictException => (409, new[]
                {
                    new ApiError(null, "STATE_CONFLICT", "La solicitud ya tiene una decisión. Actualiza la lista.")
                }),
                _ => (500, new[]
                {
                    new ApiError(null, "INTERNAL_ERROR", "Ocurrió un error inesperado. Intenta nuevamente.")
                })
            };

            if (statusCode == 500)
            {
                logger.LogError(exception, "Request failed: {TraceId}", context.TraceIdentifier);
            }

            context.Response.Clear();
            context.Response.StatusCode = statusCode;
            await context.Response.WriteAsJsonAsync(Responses.Fail(context, errors));
        }
    }
}
