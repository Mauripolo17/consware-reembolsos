import { Injectable } from '@angular/core';
import { Reimbursement, ReimbursementStatus } from '../models/reimbursement';
import { LosslessNumber } from 'lossless-json';

export function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

@Injectable({ providedIn: 'root' })
export class ReimbursementMapper {
  fromDto(value: unknown): Reimbursement {
    if (!isObject(value)) throw new Error('Invalid record');
    const status = value['status'];
    const rawAmount = value['amount'];
    if (!(rawAmount instanceof LosslessNumber) && typeof rawAmount !== 'number')
      throw new Error('Invalid monetary value');
    const amount = rawAmount.toString();
    if (!/^\d{1,16}(\.\d{1,2})?$/.test(amount) || BigInt(amount.replace('.', '')) <= 0n)
      throw new Error('Invalid monetary range');
    const [integer, fraction = ''] = amount.split('.');
    const amountDisplay =
      '$ ' +
      new Intl.NumberFormat('es-CO').format(BigInt(integer)) +
      (Number(fraction) > 0 ? ',' + fraction.padEnd(2, '0') : '');
    const isDate = (date: unknown): date is string =>
      typeof date === 'string' && date.endsWith('Z') && Number.isFinite(Date.parse(date));
    if (
      !Number.isSafeInteger(value['id']) ||
      Number(value['id']) <= 0 ||
      !['employeeName', 'category', 'description'].every(
        (key) => typeof value[key] === 'string' && value[key].trim().length > 0,
      ) ||
      !Object.values(ReimbursementStatus).includes(status as ReimbursementStatus) ||
      !isDate(value['createdAtUtc'])
    ) {
      throw new Error('Invalid record');
    }
    if (status === ReimbursementStatus.Pending) {
      if (value['decidedAtUtc'] !== null || value['rejectionReason'] !== null)
        throw new Error('Invalid pending record');
    } else if (!isDate(value['decidedAtUtc'])) throw new Error('Invalid decision date');
    if (status === ReimbursementStatus.Rejected) {
      if (typeof value['rejectionReason'] !== 'string' || !value['rejectionReason'].trim())
        throw new Error('Invalid rejection reason');
    } else if (value['rejectionReason'] !== null) throw new Error('Unexpected rejection reason');
    return {
      id: value['id'] as number,
      employeeName: value['employeeName'] as string,
      amount,
      amountDisplay,
      category: value['category'] as string,
      description: value['description'] as string,
      status: status as ReimbursementStatus,
      rejectionReason: value['rejectionReason'] as string | null,
      createdAtUtc: value['createdAtUtc'],
      decidedAtUtc: value['decidedAtUtc'] as string | null,
    };
  }

  listFromDto(value: unknown): Reimbursement[] {
    if (!Array.isArray(value)) throw new Error('Invalid list');
    return value.map((item) => this.fromDto(item));
  }
}
