using Consware.Reimbursements.Api.Contracts;
using Consware.Reimbursements.Api.Data;

namespace Consware.Reimbursements.Api.Services;

public sealed class ReimbursementMapper : IReimbursementMapper
{
    public ReimbursementDto Map(Reimbursement item) => new(
        item.Id,
        item.EmployeeName,
        item.Amount,
        item.Category,
        item.Description,
        item.Status.ToString(),
        item.RejectionReason,
        item.CreatedAtUtc,
        item.DecidedAtUtc);
}
