using Consware.Reimbursements.Api.Contracts;

namespace Consware.Reimbursements.Api.Exceptions;

public sealed class RequestValidationException(params ApiError[] errors)
    : Exception("Request validation failed.")
{
    public ApiError[] Errors { get; } = errors;
}
