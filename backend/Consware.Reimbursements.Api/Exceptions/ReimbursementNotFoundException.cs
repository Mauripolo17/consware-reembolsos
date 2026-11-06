namespace Consware.Reimbursements.Api.Exceptions;

public sealed class ReimbursementNotFoundException(int id)
    : Exception($"Reimbursement {id} was not found.");
