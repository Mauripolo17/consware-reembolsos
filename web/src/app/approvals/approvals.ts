import {
  Component,
  DestroyRef,
  ElementRef,
  inject,
  OnInit,
  signal,
  ViewChild,
} from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import {
  ApiFailure,
  Reimbursement,
  ReimbursementStatus,
  statusLabels,
} from '../models/reimbursement';
import { ReimbursementApi } from '../services/reimbursement-api';
import { MonetaryValue } from './monetary-value';

@Component({
  selector: 'app-approvals',
  imports: [FormsModule, DatePipe, MonetaryValue],
  templateUrl: './approvals.html',
  styleUrl: './approvals.scss',
})
export class Approvals implements OnInit {
  private readonly api = inject(ReimbursementApi);
  private readonly destroyRef = inject(DestroyRef);
  private generation = 0;
  private dialogTrigger: HTMLElement | null = null;
  @ViewChild('rejectionDialog') dialog!: ElementRef<HTMLDialogElement>;
  readonly statuses = Object.values(ReimbursementStatus);
  readonly statusLabels = statusLabels;
  readonly pending = ReimbursementStatus.Pending;
  readonly items = signal<Reimbursement[]>([]);
  readonly loading = signal(false);
  readonly busyId = signal<number | null>(null);
  readonly error = signal('');
  readonly notice = signal('');
  readonly traceId = signal('');
  statusFilter: ReimbursementStatus | null = ReimbursementStatus.Pending;
  selected: Reimbursement | null = null;
  reason = '';
  reasonError = '';
  dialogError = '';

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    const generation = ++this.generation;
    this.loading.set(true);
    this.error.set('');
    this.traceId.set('');
    this.items.set([]);
    this.api
      .list(this.statusFilter)
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (items) => {
          if (generation !== this.generation) return;
          this.items.set(items);
          this.loading.set(false);
        },
        error: (error: ApiFailure) => {
          if (generation !== this.generation) return;
          this.error.set(error.message);
          this.traceId.set(error.traceId);
          this.loading.set(false);
        },
      });
  }

  filterChanged(): void {
    this.notice.set('');
    this.load();
  }

  openReject(item: Reimbursement): void {
    if (this.busyId() !== null) return;
    this.dialogTrigger = document.activeElement as HTMLElement;
    this.selected = item;
    this.reason = '';
    this.reasonError = '';
    this.dialogError = '';
    this.dialog.nativeElement.showModal();
  }

  closeDialog(): void {
    if (this.busyId() !== null) return;
    this.dialog.nativeElement.close();
    this.selected = null;
    this.dialogTrigger?.focus();
  }

  cancelDialog(event: Event): void {
    event.preventDefault();
    this.closeDialog();
  }

  reject(): void {
    if (!this.selected || this.busyId() !== null) return;
    const trimmed = this.reason.trim();
    this.reasonError = !trimmed
      ? 'Escribe el motivo del rechazo.'
      : trimmed.length > 500
        ? 'El motivo no puede superar los 500 caracteres.'
        : '';
    if (this.reasonError) return;
    this.decide(this.selected, trimmed);
  }

  approve(item: Reimbursement): void {
    this.decide(item);
  }

  private decide(item: Reimbursement, reason?: string): void {
    if (this.busyId() !== null) return;
    this.busyId.set(item.id);
    this.notice.set('');
    this.error.set('');
    this.dialogError = '';
    const request =
      reason === undefined ? this.api.approve(item.id) : this.api.reject(item.id, reason);
    request.pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: () => {
        this.busyId.set(null);
        if (reason !== undefined) this.closeDialog();
        this.notice.set(
          `Solicitud #${item.id} ${reason === undefined ? 'aprobada' : 'rechazada'} correctamente.`,
        );
        this.load();
      },
      error: (error: ApiFailure) => {
        this.busyId.set(null);
        if (error.status === 409) {
          this.closeDialog();
          this.notice.set(
            'Esta solicitud ya fue resuelta. Actualizamos la lista para mostrar su estado actual.',
          );
          this.load();
        } else if (reason !== undefined) {
          this.reasonError = error.errors.find((field) => field.field === 'reason')?.message ?? '';
          this.dialogError = error.message;
        } else {
          this.error.set(error.message);
          this.traceId.set(error.traceId);
        }
      },
    });
  }
}
