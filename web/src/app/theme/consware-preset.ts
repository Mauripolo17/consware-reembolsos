import { definePreset } from '@primeuix/themes';
import Aura from '@primeuix/themes/aura';

export const ConswarePreset = definePreset(Aura, {
  primitive: {
    borderRadius: { none: '0', xs: '4px', sm: '8px', md: '12px', lg: '16px', xl: '24px' },
  },
  semantic: {
    primary: {
      50: '#eff6ff',
      100: '#dbeafe',
      200: '#bfdbfe',
      300: '#93c5fd',
      400: '#60a5fa',
      500: '#3b82f6',
      600: '#2563eb',
      700: '#1d4ed8',
      800: '#1e40af',
      900: '#1e3a8a',
      950: '#172554',
    },
    formField: { paddingX: '1rem', paddingY: '.75rem', borderRadius: '12px' },
    colorScheme: {
      light: {
        primary: {
          color: '{primary.600}',
          contrastColor: '#ffffff',
          hoverColor: '{primary.700}',
          activeColor: '{primary.800}',
        },
        highlight: {
          background: '{primary.50}',
          focusBackground: '{primary.100}',
          color: '{primary.700}',
          focusColor: '{primary.800}',
        },
        formField: {
          background: '#ffffff',
          borderColor: '#cbd5e1',
          hoverBorderColor: '#93c5fd',
          focusBorderColor: '{primary.600}',
          color: '#0f172a',
        },
      },
    },
  },
  components: {
    button: {
      root: {
        borderRadius: '12px',
        paddingX: '1rem',
        paddingY: '.75rem',
        label: { fontWeight: '600' },
      },
    },
    dialog: {
      root: { borderRadius: '24px' },
      header: { padding: '1.5rem 1.5rem 1rem' },
      content: { padding: '0 1.5rem 1.5rem' },
      footer: { padding: '1rem 1.5rem 1.5rem', gap: '.75rem' },
    },
    toast: { root: { width: '380px', borderRadius: '16px' }, summary: { fontWeight: '650' } },
    tag: {
      root: { borderRadius: '8px', padding: '.3rem .6rem', fontSize: '.75rem', fontWeight: '600' },
      colorScheme: {
        light: {
          warn: { background: '#fff7dd', color: '#9a6700' },
          success: { background: '#e7f8f0', color: '#087f5b' },
          danger: { background: '#ffedf0', color: '#b42336' },
        },
      },
    },
    datatable: {
      headerCell: { padding: '14px 20px' },
      bodyCell: { padding: '20px' },
      colorScheme: {
        light: {
          headerCell: { background: '#f8fafd', color: '#64748b', borderColor: '#e8eef5' },
          bodyCell: { borderColor: '#edf2f8' },
        },
      },
    },
  },
});
