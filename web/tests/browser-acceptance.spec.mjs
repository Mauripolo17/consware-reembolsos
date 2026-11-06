import { test, expect } from '@playwright/test';
import { runAcceptance } from './browser-acceptance.mjs';

test('real API approver workflow and responsive layouts', async ({ page }) => {
  const result = await runAcceptance(page, { artifacts: 'artifacts' });
  expect(result.results.length).toBeGreaterThanOrEqual(102);
  console.log(JSON.stringify(result));
});
