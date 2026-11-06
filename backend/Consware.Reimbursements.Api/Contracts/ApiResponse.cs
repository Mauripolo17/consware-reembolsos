namespace Consware.Reimbursements.Api.Contracts;

public record ApiError(string? Field, string Code, string Message);

public record ApiResponse<T>(
    bool Success,
    string Message,
    T? Data,
    ApiError[] Errors,
    string TraceId);
