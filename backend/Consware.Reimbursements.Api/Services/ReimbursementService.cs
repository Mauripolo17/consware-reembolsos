using Consware.Reimbursements.Api.Contracts;
using Consware.Reimbursements.Api.Data;
using Microsoft.EntityFrameworkCore;
namespace Consware.Reimbursements.Api.Services;
public sealed class ReimbursementService(ReimbursementDbContext db)
{
    private static ReimbursementDto Map(Reimbursement x) => new(x.Id, x.EmployeeName, x.Amount, x.Category, x.Description, x.Status, x.RejectionReason, x.CreatedAtUtc, x.DecidedAtUtc);
    public async Task<ReimbursementDto[]> List(string? status, string? employeeName, CancellationToken ct)
    {
        var q = db.Reimbursements.AsNoTracking();
        if (status != null) q = q.Where(x => x.Status == status);
        if (employeeName != null) q = q.Where(x => x.EmployeeName == employeeName.Trim());
        return (await q.OrderByDescending(x => x.CreatedAtUtc).ThenByDescending(x => x.Id).ToListAsync(ct)).Select(Map).ToArray();
    }
    public async Task<ReimbursementDto?> Get(int id, CancellationToken ct) => await db.Reimbursements.AsNoTracking().SingleOrDefaultAsync(x => x.Id == id, ct) is { } x ? Map(x) : null;
    public async Task<ReimbursementDto> Create(CreateRequest input, decimal amount, CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        var x = new Reimbursement { EmployeeName = input.EmployeeName!.Trim(), Amount = amount, Category = input.Category!.Trim(), Description = input.Description!.Trim(), Status = amount <= 500000m ? "Approved" : "Pending", CreatedAtUtc = now, DecidedAtUtc = amount <= 500000m ? now : null };
        db.Add(x);
        await db.SaveChangesAsync(ct);
        return Map(x);
    }
    public async Task<(ReimbursementDto? Item, bool Conflict)> Decide(int id, string status, string? reason, CancellationToken ct)
    {
        var count = await db.Reimbursements.Where(x => x.Id == id && x.Status == "Pending").ExecuteUpdateAsync(s => s.SetProperty(x => x.Status, status).SetProperty(x => x.RejectionReason, reason).SetProperty(x => x.DecidedAtUtc, (DateTime?)DateTime.UtcNow), ct);
        var item = await Get(id, ct);
        return (item, count == 0 && item != null);
    }
}
