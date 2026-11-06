import { ApplicationConfig, provideBrowserGlobalErrorListeners } from '@angular/core';
import { provideRouter } from '@angular/router';
import { provideHttpClient } from '@angular/common/http';
import { registerLocaleData } from '@angular/common';
import localeEsCo from '@angular/common/locales/es-CO';
import { providePrimeNG } from 'primeng/config';
import { MessageService } from 'primeng/api';
import { ConswarePreset } from './theme/consware-preset';
import { spanishTranslation } from './theme/spanish-translation';

import { routes } from './app.routes';

registerLocaleData(localeEsCo);

export const appConfig: ApplicationConfig = {
  providers: [
    provideBrowserGlobalErrorListeners(),
    provideRouter(routes),
    provideHttpClient(),
    MessageService,
    providePrimeNG({
      theme: { preset: ConswarePreset, options: { darkModeSelector: false } },
      translation: spanishTranslation,
      pt: {
        select: { dropdown: { 'aria-label': 'Abrir selector' } },
        table: { table: { 'aria-label': 'Solicitudes de reembolso' } },
      },
    }),
  ],
};
