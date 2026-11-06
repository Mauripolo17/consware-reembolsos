# API contract v1 (frozen)

## Transport

Base URL is supplied by client configuration, without a trailing slash. Resource path: `/api/reimbursements`. JSON uses camelCase. Client-facing text is Spanish; keys and error codes are English. Dates use ISO 8601 UTC with `Z`. Monetary JSON values are unformatted numbers in COP, at most two decimal places.

Every application success/error under `/api` returns:

```typescript
interface ApiResponse<T> {
  success: boolean;
  message: string;
  data: T | null;
  errors: ApiError[];
  traceId: string;
}
interface ApiError {
  field: string | null; // camelCase input field, or null for a general error
  code: string;        // stable English code
  message: string;     // Spanish, safe to display
}
type ReimbursementStatus = 'Pending' | 'Approved' | 'Rejected';
interface Reimbursement {
  id: number;
  employeeName: string;
  amount: number;
  category: string;
  description: string;
  status: ReimbursementStatus;
  rejectionReason: string | null;
  createdAtUtc: string;
  decidedAtUtc: string | null;
}
```

On success `errors=[]`, and `data` is an object or an array. Empty lists use `[]`. Errors use `success=false`, `data=null`, a Spanish summary, and one or more errors. `traceId` is nonempty on all responses. CORS OPTIONS and protocol HEAD responses follow HTTP body semantics; Swagger documents are not application envelopes.

## Operations

| Method | Route | Input | Success |
|---|---|---|---|
| POST | /api/reimbursements | `{employeeName,amount,category,description}` | 201 + Location + ApiResponse<Reimbursement> |
| GET | /api/reimbursements | optional status and employeeName query filters, intersected | 200 + ApiResponse<Reimbursement[]> |
| GET | /api/reimbursements/{id} | positive integer id | 200 + ApiResponse<Reimbursement> |
| PATCH | /api/reimbursements/{id}/approve | no body | 200 + ApiResponse<Reimbursement> |
| PATCH | /api/reimbursements/{id}/reject | `{reason: string}` | 200 + ApiResponse<Reimbursement> |

Lists are newest first (createdAtUtc descending, then id descending). Status accepts the three exact English values above; unknown values return 400. Employee filtering compares the trimmed complete employeeName, not substrings. Clients default to `Empleado Demo` (fixed identity, no login). UI categories: Alimentación, Transporte, Papelería, Alojamiento, Otros; API accepts any nonblank category within its length limit.

## Validation and states

- employeeName required, trimmed, max 100 characters.
- category required, trimmed, max 60; description required, trimmed, max 500.
- amount required numeric, >0, fits decimal(18,2), at most 2 meaningful decimal places; reject excess precision, do not silently round.
- amount <= 500000: Approved with decidedAtUtc equal to creation time; otherwise Pending with no decision date.
- Only Pending can become Approved or Rejected. Final states cannot change, even when requests race. Guard the SQL update on current status.
- Reject reason required, trimmed, max 500. A rejected item has a reason and a decision date. Other states have no rejection reason.

Errors: 400 invalid input/body/filter; 404 missing record or API route; 405 method not allowed; 415 unsupported media type; 409 already decided; 500 unexpected server failure. Return all field validation errors in a request where feasible. Configure ApiController InvalidModelStateResponseFactory so malformed JSON and framework errors also use this format with Spanish messages. Avoid SQL/internal exception details in responses.

Stable codes: REQUIRED, MAX_LENGTH_EXCEEDED, POSITIVE_AMOUNT_REQUIRED, INVALID_AMOUNT_PRECISION, AMOUNT_OUT_OF_RANGE, INVALID_STATUS, INVALID_ID, INVALID_JSON, INVALID_REQUEST, NOT_FOUND, STATE_CONFLICT, METHOD_NOT_ALLOWED, UNSUPPORTED_MEDIA_TYPE, INTERNAL_ERROR. A client must not depend on message wording to interpret an error.

Example invalid amount:

```json
{"success":false,"message":"Revisa los datos enviados.","data":null,"errors":[{"field":"amount","code":"POSITIVE_AMOUNT_REQUIRED","message":"El monto debe ser mayor a cero."}],"traceId":"request-id"}
```

## Client integration

Typed service owns JSON and error decoding. Flutter uses `--dart-define=API_BASE_URL=http://localhost:5000` for web and `http://10.0.2.2:5000` for Android. Angular uses environment configuration. Flutter serves port 8080, Angular port 4200; API allows those exact localhost origins. HTTP cleartext on Android is development-only. Use timeout and retry UI, never automatic mutation retries. A successful create refreshes employee requests; a decision refreshes Angular; a 409 displays the conflict and refreshes stale data.
