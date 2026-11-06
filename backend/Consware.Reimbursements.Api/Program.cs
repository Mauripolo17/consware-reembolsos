using Consware.Reimbursements.Api.Contracts;
using Consware.Reimbursements.Api.Data;
using Consware.Reimbursements.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
var builder = WebApplication.CreateBuilder(args);
builder.Services.AddDbContext<ReimbursementDbContext>(o => o.UseSqlServer(builder.Configuration.GetConnectionString("Reimbursements")));
builder.Services.AddScoped<ReimbursementService>();
builder.Services.AddControllers().ConfigureApiBehaviorOptions(o =>
{
    o.SuppressMapClientErrors = true;
    o.InvalidModelStateResponseFactory = c =>
    {
        var errors = c.ModelState.Where(x => x.Value?.Errors.Count > 0).SelectMany(x => x.Value!.Errors.Select(e =>
        {
            var field = x.Key.TrimStart('$', '.');
            if (field.Length > 0) field = char.ToLowerInvariant(field[0]) + field[1..];
            var json = e.Exception != null || x.Key.StartsWith('$');
            return new ApiError(string.IsNullOrEmpty(field) || field == "input" ? null : field, json ? "INVALID_JSON" : "INVALID_REQUEST", json ? "El cuerpo JSON no es válido." : "Revisa los datos enviados.");
        })).ToArray();
        return new BadRequestObjectResult(Responses.Fail(c.HttpContext, errors));
    };
});
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.WithOrigins("http://localhost:8080", "http://localhost:4200").AllowAnyHeader().AllowAnyMethod()));
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(o =>
{
    o.SwaggerDoc("v1", new() { Title = "Consware Reimbursements API", Version = "v1", Description = "Solicitudes de reembolso en COP. Aprobación automática hasta 500000; decisiones manuales solo para solicitudes pendientes." });
    o.MapType<System.Text.Json.JsonElement>(() => new() { Type = "number", Format = "decimal", Minimum = 0.01m, Maximum = 9999999999999999.99m, MultipleOf = 0.01m });
});
var app = builder.Build();
app.Use(async (c, next) =>
{
    try { await next(); }
    catch (Exception ex) when (!c.Response.HasStarted)
    {
        app.Logger.LogError(ex, "Request failed: {TraceId}", c.TraceIdentifier);
        c.Response.Clear();
        c.Response.StatusCode = 500;
        await c.Response.WriteAsJsonAsync(Responses.Fail(c, new ApiError(null, "INTERNAL_ERROR", "Ocurrió un error inesperado. Intenta nuevamente.")));
    }
});
app.UseStatusCodePages(async s =>
{
    var c = s.HttpContext;
    if (!c.Request.Path.StartsWithSegments("/api")) return;
    var (code, message) = c.Response.StatusCode switch
    {
        404 => ("NOT_FOUND", "No se encontró el recurso solicitado."),
        405 => ("METHOD_NOT_ALLOWED", "El método no está permitido."),
        415 => ("UNSUPPORTED_MEDIA_TYPE", "El formato del contenido no es compatible."),
        _ => ("INVALID_REQUEST", "La solicitud no es válida.")
    };
    await c.Response.WriteAsJsonAsync(Responses.Fail(c, new ApiError(null, code, message)));
});
app.UseSwagger();
app.UseSwaggerUI();
app.UseCors();
app.MapControllers();
app.Run();
