using Consware.Reimbursements.Api.Contracts;
using Consware.Reimbursements.Api.Data;
using Consware.Reimbursements.Api.Exceptions;
using Microsoft.EntityFrameworkCore;

namespace Consware.Reimbursements.Api.Services;

public sealed class ReimbursementService(
    ReimbursementDbContext db,
    IReimbursementMapper mapper)
{
    public async Task<ReimbursementDto[]> List(
        string? status,
        string? employeeName,
        CancellationToken ct)
    {
        var parsedStatus = status switch
        {
            null => (ReimbursementStatus?)null,
            "Pending" => ReimbursementStatus.Pending,
            "Approved" => ReimbursementStatus.Approved,
            "Rejected" => ReimbursementStatus.Rejected,
            _ => throw new RequestValidationException(
                new ApiError("status", "INVALID_STATUS", "El estado no es válido."))
        };
        var query = db.Reimbursements.AsNoTracking();

        if (parsedStatus != null)
        {
            query = query.Where(x => x.Status == parsedStatus.Value);
        }

        if (employeeName != null)
        {
            query = query.Where(x => x.EmployeeName == employeeName.Trim());
        }

        var items = await query
            .OrderByDescending(x => x.CreatedAtUtc)
            .ThenByDescending(x => x.Id)
            .ToListAsync(ct);

        return items.Select(mapper.Map).ToArray();
    }

    public async Task<ReimbursementDto> Get(string id, CancellationToken ct)
    {
        return mapper.Map(await Find(ParseId(id), ct));
    }

    private async Task<Reimbursement> Find(int id, CancellationToken ct)
    {
        return await db.Reimbursements
            .AsNoTracking()
            .SingleOrDefaultAsync(x => x.Id == id, ct)
            ?? throw new ReimbursementNotFoundException(id);
    }

    private static int ParseId(string id)
    {
        if (!int.TryParse(id, out var key) || key <= 0)
        {
            throw new RequestValidationException(
                new ApiError("id", "INVALID_ID", "El identificador debe ser un entero positivo."));
        }

        return key;
    }

    public async Task<ReimbursementDto> Create(
        CreateRequest input,
        CancellationToken ct)
    {
        List<ApiError> errors = [];
        Validation.Text(errors, input.EmployeeName, "employeeName", 100);
        Validation.Text(errors, input.Category, "category", 60);
        Validation.Text(errors, input.Description, "description", 500);
        var amount = Validation.Amount(input.Amount, errors);
        if (errors.Count > 0)
        {
            throw new RequestValidationException(errors.ToArray());
        }

        var now = DateTime.UtcNow;
        var item = new Reimbursement
        {
            EmployeeName = input.EmployeeName!.Trim(),
            Amount = amount,
            Category = input.Category!.Trim(),
            Description = input.Description!.Trim(),
            Status = amount <= 500000m ? ReimbursementStatus.Approved : ReimbursementStatus.Pending,
            CreatedAtUtc = now,
            DecidedAtUtc = amount <= 500000m ? now : null
        };

        db.Add(item);
        await db.SaveChangesAsync(ct);

        return mapper.Map(item);
    }

    public Task<ReimbursementDto> Approve(string id, CancellationToken ct) =>
        Decide(ParseId(id), ReimbursementStatus.Approved, null, ct);

    public Task<ReimbursementDto> Reject(string id, RejectRequest input, CancellationToken ct)
    {
        List<ApiError> errors = [];
        Validation.Text(errors, input.Reason, "reason", 500);
        if (errors.Count > 0)
        {
            throw new RequestValidationException(errors.ToArray());
        }

        return Decide(ParseId(id), ReimbursementStatus.Rejected, input.Reason!.Trim(), ct);
    }

    private async Task<ReimbursementDto> Decide(
        int id,
        ReimbursementStatus status,
        string? reason,
        CancellationToken ct)
    {
        var count = await db.Reimbursements
            .Where(x => x.Id == id && x.Status == ReimbursementStatus.Pending)
            .ExecuteUpdateAsync(
                setters => setters
                    .SetProperty(x => x.Status, status)
                    .SetProperty(x => x.RejectionReason, reason)
                    .SetProperty(x => x.DecidedAtUtc, (DateTime?)DateTime.UtcNow),
                ct);

        var item = await Find(id, ct);
        if (count == 0)
        {
            throw new ReimbursementStateConflictException(id);
        }

        return mapper.Map(item);
    }
}
