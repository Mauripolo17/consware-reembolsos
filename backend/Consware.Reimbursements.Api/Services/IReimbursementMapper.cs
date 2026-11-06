using Consware.Reimbursements.Api.Contracts;
using Consware.Reimbursements.Api.Data;

namespace Consware.Reimbursements.Api.Services;

public interface IReimbursementMapper
{
    ReimbursementDto Map(Reimbursement item);
}
