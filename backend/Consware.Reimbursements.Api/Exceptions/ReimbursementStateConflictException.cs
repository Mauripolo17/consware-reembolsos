namespace Consware.Reimbursements.Api.Exceptions;

public sealed class ReimbursementStateConflictException(int id)
    : Exception($"Reimbursement {id} already has a decision.");
