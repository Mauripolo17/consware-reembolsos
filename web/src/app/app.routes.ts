import { Routes } from '@angular/router';

export const routes: Routes = [
  {
    path: '',
    loadComponent: () => import('./approvals/approvals').then((module) => module.Approvals),
  },
  { path: '**', redirectTo: '' },
];
