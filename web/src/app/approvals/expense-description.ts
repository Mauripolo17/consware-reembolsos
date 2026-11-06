import { Component, input, signal } from '@angular/core';

@Component({
  selector: 'app-expense-description',
  template: `<p>{{ expanded() || text().length <= 160 ? text() : text().slice(0, 160) + '…' }}</p>
    @if (text().length > 160) {
      <button type="button" (click)="expanded.set(!expanded())" [attr.aria-expanded]="expanded()">
        {{ expanded() ? 'Ver menos' : 'Leer descripción completa' }}
      </button>
    }`,
  styles: `
    :host {
      display: block;
      min-width: 0;
    }
    p {
      margin: 0;
      color: #475569;
      font-size: 14px;
      line-height: 1.6;
      white-space: pre-wrap;
      overflow-wrap: anywhere;
    }
    button {
      min-height: 48px;
      padding: 4px 0;
      background: transparent;
      border: 0;
      font: inherit;
      font-size: 13px;
      color: #1d4ed8;
      font-weight: 600;
      cursor: pointer;
    }
  `,
})
export class ExpenseDescription {
  readonly text = input.required<string>();
  readonly expanded = signal(false);
}
