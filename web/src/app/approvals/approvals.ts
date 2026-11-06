import {
  Component,
  DestroyRef,
  ElementRef,
  inject,
  HostListener,
  OnInit,
  signal,
  ViewChild,
} from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { MessageService } from 'primeng/api';
import { ButtonModule } from 'primeng/button';
import { DialogModule } from 'primeng/dialog';
import { SelectModule } from 'primeng/select';
import { TableModule } from 'primeng/table';
import { TagModule } from 'primeng/tag';
import { TextareaModule } from 'primeng/textarea';
import { ProgressSpinnerModule } from 'primeng/progressspinner';
import { PaginatorModule, PaginatorState } from 'primeng/paginator';
import { TooltipModule } from 'primeng/tooltip';
import {
  ApiFailure,
  Reimbursement,
  ReimbursementStatus,
  statusLabels,
} from '../models/reimbursement';
import { ReimbursementApi } from '../services/reimbursement-api';
import { MonetaryValue } from './monetary-value';
import { ExpenseDescription } from './expense-description';

@Component({
  selector: 'app-approvals',
  imports: [
    FormsModule,
    DatePipe,
    MonetaryValue,
    ExpenseDescription,
    ButtonModule,
    DialogModule,
    SelectModule,
    TableModule,
    TagModule,
    TextareaModule,
    ProgressSpinnerModule,
    PaginatorModule,
    TooltipModule,
  ],
  templateUrl: './approvals.html',
  styleUrl: './approvals.scss',
})
export class Approvals implements OnInit {
  private readonly api = inject(ReimbursementApi);
  private readonly messages = inject(MessageService);
  private readonly destroyRef = inject(DestroyRef);
  private generation = 0;
  private dialogTrigger: HTMLElement | null = null;
  @ViewChild('reasonInput') reasonInput?: ElementRef<HTMLTextAreaElement>;
  @ViewChild('cancelButton', { read: ElementRef }) cancelButton?: ElementRef<HTMLElement>;
  readonly statusOptions = [
    { label: 'Todos los estados', value: null },
    ...Object.values(ReimbursementStatus).map((value) => ({ label: statusLabels[value], value })),
  ];
  readonly statusLabels = statusLabels;
  readonly pending = ReimbursementStatus.Pending;
  readonly items = signal<Reimbursement[]>([]);
  readonly loading = signal(false);
  readonly busyId = signal<number | null>(null);
  readonly error = signal('');
  readonly traceId = signal('');
  statusFilter: ReimbursementStatus | null = ReimbursementStatus.Pending;
  selected: Reimbursement | null = null;
  dialogVisible = false;
  decisionStep: 'reason' | 'confirmApproval' | 'confirmRejection' = 'reason';
  confirmedReason = '';
  reason = '';
  reasonError = '';
  dialogError = '';
  first = 0;
  pageSize = 8;

  get pagedItems(): Reimbursement[] {
    return this.items().slice(this.first, this.first + this.pageSize);
  }
  get dialogTitle(): string {
    if (this.decisionStep === 'confirmApproval') return 'Confirmar aprobación';
    if (this.decisionStep === 'confirmRejection') return 'Confirmar rechazo';
    return `Rechazar solicitud #${this.selected?.id}`;
  }
  get resultTitle(): string {
    switch (this.statusFilter) {
      case ReimbursementStatus.Pending:
        return 'Por revisar';
      case ReimbursementStatus.Approved:
        return 'Solicitudes aprobadas';
      case ReimbursementStatus.Rejected:
        return 'Solicitudes rechazadas';
      default:
        return 'Todas las solicitudes';
    }
  }

  ngOnInit(): void {
    this.load();
  }

  load(): void {
    const generation = ++this.generation;
    this.loading.set(true);
    this.error.set('');
    this.traceId.set('');
    this.items.set([]);
    this.first = 0;
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
          this.notify('error', 'No pudimos cargar las solicitudes', error.message);
        },
      });
  }

  filterChanged(): void {
    this.load();
  }

  pageChanged(event: PaginatorState): void {
    this.first = event.first ?? 0;
    this.pageSize = event.rows ?? 8;
  }

  initials(name: string): string {
    return name
      .trim()
      .split(/\s+/)
      .slice(0, 2)
      .map((part) => part[0])
      .join('')
      .toUpperCase();
  }

  statusSeverity(status: ReimbursementStatus): 'warn' | 'success' | 'danger' {
    return status === ReimbursementStatus.Pending
      ? 'warn'
      : status === ReimbursementStatus.Approved
        ? 'success'
        : 'danger';
  }

  statusLabel(status: ReimbursementStatus): string {
    return statusLabels[status];
  }

  categoryIcon(category: string): string {
    const icons: Record<string, string> = {
      Transporte: 'pi-car',
      Alimentación: 'pi-shop',
      Alojamiento: 'pi-building',
      Papelería: 'pi-file',
    };
    return icons[category] ?? 'pi-receipt';
  }

  openReject(item: Reimbursement): void {
    if (this.busyId() !== null) return;
    this.messages.clear();
    this.dialogTrigger = document.activeElement as HTMLElement;
    this.selected = item;
    this.decisionStep = 'reason';
    this.reason = '';
    this.reasonError = '';
    this.dialogError = '';
    this.dialogVisible = true;
  }

  focusReason(): void {
    this.reasonInput?.nativeElement.focus();
  }

  focusDialog(): void {
    if (this.decisionStep === 'reason') this.focusReason();
    else this.cancelButton?.nativeElement.querySelector('button')?.focus();
  }

  closeDialog(): void {
    if (this.busyId() === null) this.dialogVisible = false;
  }

  cancelDecision(): void {
    if (this.busyId() !== null) return;
    if (this.decisionStep === 'confirmRejection') {
      this.decisionStep = 'reason';
      setTimeout(() => this.focusReason());
    } else this.closeDialog();
  }

  @HostListener('document:keydown.escape', ['$event'])
  onEscape(event: Event): void {
    if (!this.dialogVisible) return;
    event.preventDefault();
    event.stopPropagation();
    this.cancelDecision();
  }

  dialogVisibilityChanged(visible: boolean): void {
    if (this.busyId() === null) this.dialogVisible = visible;
  }

  restoreDialogFocus(): void {
    this.selected = null;
    if (this.dialogTrigger?.isConnected) this.dialogTrigger.focus();
  }

  reject(): void {
    if (!this.selected || this.busyId() !== null) return;
    const trimmed = this.reason.trim();
    this.reasonError = !trimmed
      ? 'Escribe el motivo del rechazo.'
      : trimmed.length > 500
        ? 'El motivo no puede superar los 500 caracteres.'
        : '';
    if (this.reasonError) {
      this.focusReason();
      return;
    }
    this.confirmedReason = trimmed;
    this.decisionStep = 'confirmRejection';
    setTimeout(() => this.focusDialog());
  }

  approve(item: Reimbursement): void {
    if (this.busyId() !== null) return;
    this.messages.clear();
    this.dialogTrigger = document.activeElement as HTMLElement;
    this.selected = item;
    this.decisionStep = 'confirmApproval';
    this.dialogError = '';
    this.dialogVisible = true;
  }

  confirmDecision(): void {
    if (!this.selected || this.busyId() !== null || this.decisionStep === 'reason') return;
    this.decide(
      this.selected,
      this.decisionStep === 'confirmRejection' ? this.confirmedReason : undefined,
    );
  }

  private notify(severity: 'success' | 'info' | 'error', summary: string, detail: string): void {
    this.messages.clear();
    this.messages.add({ severity, summary, detail, life: severity === 'success' ? 6000 : 8000 });
  }

  private decide(item: Reimbursement, reason?: string): void {
    if (this.busyId() !== null) return;
    this.busyId.set(item.id);
    this.dialogError = '';
    const request =
      reason === undefined ? this.api.approve(item.id) : this.api.reject(item.id, reason);
    request.pipe(takeUntilDestroyed(this.destroyRef)).subscribe({
      next: () => {
        this.busyId.set(null);
        this.closeDialog();
        this.notify(
          'success',
          reason === undefined ? 'Reembolso aprobado' : 'Solicitud rechazada',
          `Solicitud #${item.id} ${reason === undefined ? 'aprobada' : 'rechazada'} correctamente.`,
        );
        this.load();
      },
      error: (error: ApiFailure) => {
        this.busyId.set(null);
        if (error.status === 409) {
          this.closeDialog();
          this.notify(
            'info',
            'La solicitud ya fue resuelta',
            'Esta solicitud ya fue resuelta. Actualizamos la lista para mostrar su estado actual.',
          );
          this.load();
        } else {
          if (reason !== undefined) {
            this.reasonError =
              error.errors.find((field) => field.field === 'reason')?.message ?? '';
            this.dialogError = error.message;
          }
          this.notify('error', 'No pudimos guardar la decisión', error.message);
        }
      },
    });
  }
}
