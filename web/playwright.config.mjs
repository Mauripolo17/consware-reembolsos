import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.spec.mjs',
  timeout: 120000,
  workers: 1,
  reporter: 'list',
  outputDir: './artifacts/test-results',
  use: { channel: 'msedge', headless: true, locale: 'es-CO', actionTimeout: 15000 },
});
