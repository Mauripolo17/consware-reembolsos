import { HttpClient, HttpErrorResponse, HttpParams } from '@angular/common/http';
import { inject, Injectable } from '@angular/core';
import { catchError, map, Observable, throwError, timeout, TimeoutError } from 'rxjs';
import { environment } from '../../environments/environment';
import {
  ApiError,
  ApiFailure,
  ApiResponse,
  Reimbursement,
  ReimbursementStatus,
} from '../models/reimbursement';
import { isObject, ReimbursementMapper } from './reimbursement-mapper';
import { LosslessNumber, parse } from 'lossless-json';

@Injectable({ providedIn: 'root' })
export class ReimbursementApi {
  private readonly http = inject(HttpClient);
  private readonly mapper = inject(ReimbursementMapper);
  private readonly url = environment.apiBaseUrl.replace(/\/$/, '') + '/api/reimbursements';

  list(status: ReimbursementStatus | null): Observable<Reimbursement[]> {
    const params = status ? new HttpParams().set('status', status) : new HttpParams();
    return this.request(this.http.get(this.url, { params, responseType: 'text' }), (data) =>
      this.mapper.listFromDto(data),
    );
  }

  approve(id: number): Observable<Reimbursement> {
    return this.request(
      this.http.patch(`${this.url}/${id}/approve`, null, { responseType: 'text' }),
      (data) => this.mapper.fromDto(data),
      true,
    );
  }

  reject(id: number, reason: string): Observable<Reimbursement> {
    return this.request(
      this.http.patch(
        `${this.url}/${id}/reject`,
        { reason: reason.trim() },
        { responseType: 'text' },
      ),
      (data) => this.mapper.fromDto(data),
      true,
    );
  }

  private envelope(value: unknown): ApiResponse<unknown> {
    if (typeof value === 'string') {
      value = parse(value, undefined, (token) =>
        /^-?\d+$/.test(token) && Number.isSafeInteger(Number(token))
          ? Number(token)
          : new LosslessNumber(token),
      );
    }
    if (
      !isObject(value) ||
      typeof value['success'] !== 'boolean' ||
      typeof value['message'] !== 'string' ||
      !value['message'].trim() ||
      typeof value['traceId'] !== 'string' ||
      !value['traceId'].trim() ||
      !('data' in value) ||
      !Array.isArray(value['errors'])
    )
      throw new Error('Invalid envelope');
    const errors: ApiError[] = value['errors'].map((error: unknown) => {
      if (
        !isObject(error) ||
        !(error['field'] === null || typeof error['field'] === 'string') ||
        typeof error['code'] !== 'string' ||
        !error['code'] ||
        typeof error['message'] !== 'string' ||
        !error['message'].trim()
      )
        throw new Error('Invalid error');
      return { field: error['field'], code: error['code'], message: error['message'] } as ApiError;
    });
    if (
      value['success']
        ? errors.length > 0 || value['data'] === null
        : errors.length === 0 || value['data'] !== null
    )
      throw new Error('Inconsistent envelope');
    return {
      success: value['success'],
      message: value['message'],
      traceId: value['traceId'],
      data: value['data'],
      errors,
    };
  }

  private request<T>(
    source: Observable<unknown>,
    parse: (data: unknown) => T,
    mutation = false,
  ): Observable<T> {
    return source.pipe(
      timeout(12000),
      map((raw) => {
        const response = this.envelope(raw);
        if (!response.success)
          throw new ApiFailure(response.message, 0, response.errors, response.traceId);
        return parse(response.data);
      }),
      catchError((error: unknown) => {
        if (error instanceof ApiFailure) return throwError(() => error);
        if (error instanceof HttpErrorResponse && error.status > 0) {
          try {
            const response = this.envelope(error.error);
            if (!response.success)
              return throwError(
                () =>
                  new ApiFailure(response.message, error.status, response.errors, response.traceId),
              );
          } catch {
            /* Replace invalid server responses with safe Spanish text. */
          }
        }
        const network =
          error instanceof TimeoutError ||
          (error instanceof HttpErrorResponse && error.status === 0);
        const message = network
          ? mutation
            ? 'No recibimos confirmación del servidor. Actualiza la lista antes de volver a enviar la decisión.'
            : 'No pudimos conectar con el servidor. Verifica la conexión e intenta de nuevo.'
          : 'El servidor devolvió una respuesta que no pudimos interpretar. Intenta actualizar la lista.';
        return throwError(() => new ApiFailure(message));
      }),
    );
  }
}
