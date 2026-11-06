export enum ReimbursementStatus {
  Pending = 'Pending',
  Approved = 'Approved',
  Rejected = 'Rejected',
}

export const statusLabels: Record<ReimbursementStatus, string> = {
  [ReimbursementStatus.Pending]: 'Pendiente',
  [ReimbursementStatus.Approved]: 'Aprobado',
  [ReimbursementStatus.Rejected]: 'Rechazado',
};

export interface Reimbursement {
  id: number;
  employeeName: string;
  // Decimal text preserves API monetary values beyond JavaScript Number precision.
  amount: string;
  amountDisplay: string;
  category: string;
  description: string;
  status: ReimbursementStatus;
  rejectionReason: string | null;
  createdAtUtc: string;
  decidedAtUtc: string | null;
}

export interface ApiError {
  field: string | null;
  code: string;
  message: string;
}

export interface ApiResponse<T> {
  success: boolean;
  message: string;
  data: T | null;
  errors: ApiError[];
  traceId: string;
}

export class ApiFailure extends Error {
  constructor(
    message: string,
    readonly status = 0,
    readonly errors: ApiError[] = [],
    readonly traceId = '',
  ) {
    super(message);
  }
}
