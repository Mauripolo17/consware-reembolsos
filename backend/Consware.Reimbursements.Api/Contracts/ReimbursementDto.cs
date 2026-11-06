namespace Consware.Reimbursements.Api.Contracts;

public record ReimbursementDto(
    int Id,
    string EmployeeName,
    decimal Amount,
    string Category,
    string Description,
    string Status,
    string? RejectionReason,
    DateTime CreatedAtUtc,
    DateTime? DecidedAtUtc);
