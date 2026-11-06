import { Component } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { ToastModule } from 'primeng/toast';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, ToastModule],
  template: `<router-outlet /><p-toast
      position="top-right"
      [baseZIndex]="3000"
      [preventOpenDuplicates]="true"
      [breakpoints]="{ '599px': { width: 'calc(100% - 32px)', right: '16px', top: '16px' } }"
    />`,
})
export class App {}
