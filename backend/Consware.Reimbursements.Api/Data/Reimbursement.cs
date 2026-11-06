namespace Consware.Reimbursements.Api.Data;

public sealed class Reimbursement
{
    public int Id { get; set; }
    public string EmployeeName { get; set; } = "";
    public decimal Amount { get; set; }
    public string Category { get; set; } = "";
    public string Description { get; set; } = "";
    public ReimbursementStatus Status { get; set; } = ReimbursementStatus.Pending;
    public string? RejectionReason { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? DecidedAtUtc { get; set; }
}
