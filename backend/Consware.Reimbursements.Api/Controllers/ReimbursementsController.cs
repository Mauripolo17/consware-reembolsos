using Consware.Reimbursements.Api.Contracts;
using Consware.Reimbursements.Api.Services;
using Microsoft.AspNetCore.Mvc;

namespace Consware.Reimbursements.Api.Controllers;

[ApiController]
[Route("api/reimbursements")]
[Produces("application/json")]
[ProducesResponseType(typeof(ApiResponse<object>), 400)]
[ProducesResponseType(typeof(ApiResponse<object>), 404)]
[ProducesResponseType(typeof(ApiResponse<object>), 409)]
[ProducesResponseType(typeof(ApiResponse<object>), 415)]
[ProducesResponseType(typeof(ApiResponse<object>), 500)]
public sealed class ReimbursementsController(ReimbursementService service) : ControllerBase
{
    private ObjectResult Error(int status, string code, string message, string? field = null)
    {
        return StatusCode(status, Responses.Fail(HttpContext, new ApiError(field, code, message)));
    }

    [HttpGet]
    [ProducesResponseType(typeof(ApiResponse<ReimbursementDto[]>), 200)]
    public async Task<IActionResult> List(
        [FromQuery] string? status,
        [FromQuery] string? employeeName,
        CancellationToken ct)
    {
        if (Request.Query.ContainsKey("status") && status is not ("Pending" or "Approved" or "Rejected"))
        {
            return Error(400, "INVALID_STATUS", "El estado no es válido.", "status");
        }

        return Ok(Responses.Ok(HttpContext, await service.List(status, employeeName, ct)));
    }

    [HttpGet("{id}")]
    [ProducesResponseType(typeof(ApiResponse<ReimbursementDto>), 200)]
    public async Task<IActionResult> Get(string id, CancellationToken ct)
    {
        if (!int.TryParse(id, out var key) || key <= 0)
        {
            return Error(400, "INVALID_ID", "El identificador debe ser un entero positivo.", "id");
        }

        var item = await service.Get(key, ct);
        return item == null
            ? Error(404, "NOT_FOUND", "No se encontró la solicitud.")
            : Ok(Responses.Ok(HttpContext, item));
    }

    [HttpPost]
    [ProducesResponseType(typeof(ApiResponse<ReimbursementDto>), 201)]
    public async Task<IActionResult> Create([FromBody] CreateRequest input, CancellationToken ct)
    {
        List<ApiError> errors = [];
        Validation.Text(errors, input.EmployeeName, "employeeName", 100);
        Validation.Text(errors, input.Category, "category", 60);
        Validation.Text(errors, input.Description, "description", 500);
        var amount = Validation.Amount(input.Amount, errors);
        if (errors.Count > 0)
        {
            return BadRequest(Responses.Fail(HttpContext, errors.ToArray()));
        }

        var item = await service.Create(input, amount, ct);
        return CreatedAtAction(nameof(Get), new { id = item.Id }, Responses.Ok(HttpContext, item));
    }

    [HttpPatch("{id}/approve")]
    [ProducesResponseType(typeof(ApiResponse<ReimbursementDto>), 200)]
    public Task<IActionResult> Approve(string id, CancellationToken ct) => Decide(id, "Approved", null, ct);

    [HttpPatch("{id}/reject")]
    [ProducesResponseType(typeof(ApiResponse<ReimbursementDto>), 200)]
    public async Task<IActionResult> Reject(string id, [FromBody] RejectRequest input, CancellationToken ct)
    {
        List<ApiError> errors = [];
        Validation.Text(errors, input.Reason, "reason", 500);
        if (errors.Count > 0)
        {
            return BadRequest(Responses.Fail(HttpContext, errors.ToArray()));
        }

        return await Decide(id, "Rejected", input.Reason!.Trim(), ct);
    }

    private async Task<IActionResult> Decide(string id, string status, string? reason, CancellationToken ct)
    {
        if (!int.TryParse(id, out var key) || key <= 0)
        {
            return Error(400, "INVALID_ID", "El identificador debe ser un entero positivo.", "id");
        }

        var (item, conflict) = await service.Decide(key, status, reason, ct);
        if (item == null)
        {
            return Error(404, "NOT_FOUND", "No se encontró la solicitud.");
        }

        return conflict
            ? Error(409, "STATE_CONFLICT", "La solicitud ya tiene una decisión. Actualiza la lista.")
            : Ok(Responses.Ok(HttpContext, item));
    }
}
