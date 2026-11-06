using Microsoft.EntityFrameworkCore;
namespace Consware.Reimbursements.Api.Data;
public sealed class Reimbursement
{
    public int Id { get; set; }
    public string EmployeeName { get; set; } = "";
    public decimal Amount { get; set; }
    public string Category { get; set; } = "";
    public string Description { get; set; } = "";
    public string Status { get; set; } = "Pending";
    public string? RejectionReason { get; set; }
    public DateTime CreatedAtUtc { get; set; }
    public DateTime? DecidedAtUtc { get; set; }
}
public sealed class ReimbursementDbContext(DbContextOptions<ReimbursementDbContext> options) : DbContext(options)
{
    public DbSet<Reimbursement> Reimbursements => Set<Reimbursement>();
    protected override void OnModelCreating(ModelBuilder builder)
    {
        var e = builder.Entity<Reimbursement>();
        e.Property(x => x.EmployeeName).HasMaxLength(100).IsRequired();
        e.Property(x => x.Category).HasMaxLength(60).IsRequired();
        e.Property(x => x.Description).HasMaxLength(500).IsRequired();
        e.Property(x => x.Amount).HasPrecision(18, 2);
        e.Property(x => x.Status).HasMaxLength(8).IsRequired();
        e.Property(x => x.RejectionReason).HasMaxLength(500);
        e.HasIndex(x => x.Status);
        e.HasIndex(x => x.EmployeeName);
        e.Property(x => x.CreatedAtUtc).HasConversion(v => v, v => DateTime.SpecifyKind(v, DateTimeKind.Utc));
        e.Property(x => x.DecidedAtUtc).HasConversion(v => v, v => v.HasValue ? DateTime.SpecifyKind(v.Value, DateTimeKind.Utc) : null);
        e.ToTable(t => t.HasCheckConstraint("CK_Reimbursements_State", "([Status] = 'Pending' AND [DecidedAtUtc] IS NULL AND [RejectionReason] IS NULL) OR ([Status] = 'Approved' AND [DecidedAtUtc] IS NOT NULL AND [RejectionReason] IS NULL) OR ([Status] = 'Rejected' AND [DecidedAtUtc] IS NOT NULL AND [RejectionReason] IS NOT NULL AND LEN([RejectionReason]) > 0)"));
    }
}
