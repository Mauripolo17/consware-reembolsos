using Consware.Reimbursements.Api.Contracts;
using Consware.Reimbursements.Api.Data;
using Microsoft.EntityFrameworkCore;

namespace Consware.Reimbursements.Api.Services;

public sealed class ReimbursementService(ReimbursementDbContext db)
{
    private static ReimbursementDto Map(Reimbursement item) => new(
        item.Id,
        item.EmployeeName,
        item.Amount,
        item.Category,
        item.Description,
        item.Status,
        item.RejectionReason,
        item.CreatedAtUtc,
        item.DecidedAtUtc);

    public async Task<ReimbursementDto[]> List(
        string? status,
        string? employeeName,
        CancellationToken ct)
    {
        var query = db.Reimbursements.AsNoTracking();

        if (status != null)
        {
            query = query.Where(x => x.Status == status);
        }

        if (employeeName != null)
        {
            query = query.Where(x => x.EmployeeName == employeeName.Trim());
        }

        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .ToListAsync(ct);

        return items.Select(Map).ToArray();
    }

    public async Task<ReimbursementDto?> Get(int id, CancellationToken ct)
    {
        var item = await db.Reimbursements
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id, ct);

        return item is not null ? Map(item) : null;
    }

    public async Task<ReimbursementDto> Create(
        CreateRequest input,
        decimal amount,
        CancellationToken ct)
    {
        var now = DateTime.UtcNow;
        var item = new Reimbursement
        {
            EmployeeName = input.EmployeeName!.Trim(),
            Amount = amount,
            Category = input.Category!.Trim(),
            Description = input.Description!.Trim(),
            Status = amount <= 500000m ? "Approved" : "Pending",
            CreatedAtUtc = now,
            DecidedAtUtc = amount <= 500000m ? now : null
        };

        db.Add(item);
        await db.SaveChangesAsync(ct);

        return Map(item);
    }

    public async Task<(ReimbursementDto? Item, bool Conflict)> Decide(
        int id,
        string status,
        string? reason,
        CancellationToken ct)
    {
        var count = await db.Reimbursements
            .Where(x => x.Id == id && x.Status == "Pending")
            .ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(x => x.Status, status)
                    .SetProperty(x => x.RejectionReason, reason)
                    .SetProperty(x => x.DecidedAtUtc, (DateTime?)DateTime.UtcNow),
                ct);

        var item = await Get(id, ct);
        return (item, count == 0 && item != null);
    }
}
