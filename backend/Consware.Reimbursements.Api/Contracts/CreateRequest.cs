using System.Text.Json;

namespace Consware.Reimbursements.Api.Contracts;

public sealed class CreateRequest
{
    public string? EmployeeName { get; set; }
    public JsonElement Amount { get; set; }
    public string? Category { get; set; }
    public string? Description { get; set; }
}
