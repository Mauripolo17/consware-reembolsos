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
    [HttpGet]
    [ProducesResponseType(typeof(ApiResponse<ReimbursementDto[]>), 200)]
    public async Task<IActionResult> List(
        [FromQuery] string? status,
        [FromQuery] string? employeeName,
        CancellationToken ct)
    {
        var filter = Request.Query.ContainsKey("status") ? status ?? "" : null;
        var items = await service.List(filter, employeeName, ct);
        return Ok(Responses.Ok(HttpContext, items));
    }

    [HttpGet("{id}")]
    [ProducesResponseType(typeof(ApiResponse<ReimbursementDto>), 200)]
    public async Task<IActionResult> Get(string id, CancellationToken ct)
    {
        var item = await service.Get(id, ct);
        return Ok(Responses.Ok(HttpContext, item));
    }

    [HttpPost]
    [ProducesResponseType(typeof(ApiResponse<ReimbursementDto>), 201)]
    public async Task<IActionResult> Create([FromBody] CreateRequest input, CancellationToken ct)
    {
        var item = await service.Create(input, ct);
        return CreatedAtAction(nameof(Get), new { id = item.Id }, Responses.Ok(HttpContext, item));
    }

    [HttpPatch("{id}/approve")]
    [ProducesResponseType(typeof(ApiResponse<ReimbursementDto>), 200)]
    public async Task<IActionResult> Approve(string id, CancellationToken ct)
    {
        var item = await service.Approve(id, ct);
        return Ok(Responses.Ok(HttpContext, item));
    }

    [HttpPatch("{id}/reject")]
    [ProducesResponseType(typeof(ApiResponse<ReimbursementDto>), 200)]
    public async Task<IActionResult> Reject(string id, [FromBody] RejectRequest input, CancellationToken ct)
    {
        var item = await service.Reject(id, input, ct);
        return Ok(Responses.Ok(HttpContext, item));
    }
}
