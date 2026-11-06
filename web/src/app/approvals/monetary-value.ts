import { Component, computed, input } from '@angular/core';

@Component({
  selector: 'app-monetary-value',
  template:
    '@for (part of parts(); track $index) {<span>{{ part }}@if (!$last) {.}</span>@if (!$last) {<wbr>}}',
  styles: ':host { overflow-wrap: normal; } span { white-space: nowrap; }',
})
export class MonetaryValue {
  readonly value = input.required<string>();
  readonly parts = computed(() => this.value().split('.'));
}
