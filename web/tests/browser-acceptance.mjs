import { mkdir } from 'node:fs/promises';
import { resolve } from 'node:path';

// Run with a fresh Playwright page and the real local SQL-backed API.
export async function runAcceptance(page, options = {}) {
  const baseUrl = options.baseUrl ?? 'http://localhost:4200';
  const apiBaseUrl = options.apiBaseUrl ?? 'http://127.0.0.1:5000';
  const artifacts = resolve(options.artifacts ?? 'web/artifacts');
  await mkdir(artifacts, { recursive: true });
  const results = [];
  const check = (condition, message) => {
    if (!condition) throw new Error(message);
    results.push(message);
  };
  const name = `Angular-${Date.now()}`;
  const create = async (description) => {
    const response = await page.request.post(`${apiBaseUrl}/api/reimbursements`, {
      data: { employeeName: name, amount: 500000.01, category: 'Transporte', description },
    });
    if (response.status() !== 201) throw new Error(`Fixture creation HTTP ${response.status()}`);
    return (await response.json()).data;
  };
  const approved = await create('Visita de trabajo: aprobación desde el panel Angular.');
  const rejected = await create('Visita de trabajo: rechazo desde el panel Angular.');
  const conflict = await create('Visita de trabajo: conflicto entre dos aprobadores.');
  const maximumResponse = await page.request.post(`${apiBaseUrl}/api/reimbursements`, {
    headers: { 'Content-Type': 'application/json' },
    data: `{"employeeName":"${name}","amount":9999999999999999.99,"category":"Otros","description":"Importe máximo para verificar lectura monetaria exacta."}`,
  });
  if (maximumResponse.status() !== 201) throw new Error('Maximum amount fixture failed');
  const maximum = (await maximumResponse.json()).data;
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto(baseUrl);
  const filter = page.getByLabel('Estado de la solicitud');
  const waitLoaded = async () => {
    await page.waitForFunction(
      () => document.querySelector('[aria-busy]')?.getAttribute('aria-busy') === 'false',
    );
  };
  const select = async (label) => {
    await filter.selectOption({ label });
    await waitLoaded();
  };
  const row = (id) => page.locator(`.desktop-table [data-id="${id}"]`);
  await waitLoaded();
  check((await filter.locator('option:checked').innerText()) === 'Pendiente', 'Pending default');
  check(await row(approved.id).isVisible(), 'Real pending fixture visible');
  check(
    (await row(maximum.id).locator('.amount').innerText()).includes('9.999.999.999.999.999,99'),
    'Maximum decimal amount displayed exactly',
  );
  for (const width of [360, 768, 1440]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.evaluate(() => scrollTo(0, 0));
    check(
      await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth),
      `No page overflow at ${width}`,
    );
    check(
      await page.locator(width >= 1024 ? '.desktop-table' : '.request-cards').isVisible(),
      `Correct layout at ${width}`,
    );
    await page.screenshot({ path: resolve(artifacts, `angular-${width}.png`), fullPage: false });
    const target =
      width >= 1024 ? row(rejected.id) : page.locator(`.request-cards [data-id="${rejected.id}"]`);
    await target.getByRole('button', { name: 'Rechazar', exact: true }).click();
    const dialog = page.getByRole('dialog');
    await dialog.waitFor();
    check(
      await dialog.evaluate((element) => {
        const rect = element.getBoundingClientRect();
        return rect.left >= 0 && rect.right <= innerWidth && rect.height <= innerHeight;
      }),
      `Dialog fits at ${width}`,
    );
    await page.screenshot({
      path: resolve(artifacts, `angular-dialog-${width}.png`),
      fullPage: false,
    });
    await page.keyboard.press('Escape');
    check(!(await dialog.isVisible()), `Escape closes dialog at ${width}`);
  }
  let approvalRequests = 0;
  await page.route(`**/api/reimbursements/${approved.id}/approve`, async (route) => {
    approvalRequests++;
    const response = await route.fetch();
    await new Promise((resolve) => setTimeout(resolve, 300));
    await route.fulfill({ response });
  });
  const approveButton = row(approved.id).getByRole('button', { name: 'Aprobar', exact: true });
  await approveButton.click();
  check(
    await row(approved.id).getByRole('button', { name: 'Procesando…' }).isDisabled(),
    'Repeated mutation disabled while pending',
  );
  await row(approved.id)
    .getByRole('button', { name: 'Procesando…' })
    .evaluate((button) => button.click());
  await page
    .getByRole('status')
    .filter({ hasText: `Solicitud #${approved.id} aprobada` })
    .waitFor();
  await waitLoaded();
  check(approvalRequests === 1, 'Exactly one approval request sent');
  await page.unroute(`**/api/reimbursements/${approved.id}/approve`);
  check(
    (
      await page.request
        .get(`${apiBaseUrl}/api/reimbursements/${approved.id}`)
        .then((r) => r.json())
    ).data.status === 'Approved',
    'UI approval persisted in real API',
  );
  await row(rejected.id).getByRole('button', { name: 'Rechazar', exact: true }).click();
  await page.getByRole('button', { name: 'Confirmar rechazo' }).click();
  check(
    await page.getByText('Escribe el motivo del rechazo.', { exact: true }).isVisible(),
    'Blank rejection blocked',
  );
  await page.getByLabel('Motivo del rechazo (obligatorio)').fill('   ');
  await page.getByRole('button', { name: 'Confirmar rechazo' }).click();
  check(
    await page.getByText('Escribe el motivo del rechazo.', { exact: true }).isVisible(),
    'Whitespace rejection blocked',
  );
  await page
    .getByLabel('Motivo del rechazo (obligatorio)')
    .fill('  Falta el detalle de la actividad corporativa.  ');
  await page.getByRole('button', { name: 'Confirmar rechazo' }).click();
  await page
    .getByRole('status')
    .filter({ hasText: `Solicitud #${rejected.id} rechazada` })
    .waitFor();
  await waitLoaded();
  const stored = (
    await page.request.get(`${apiBaseUrl}/api/reimbursements/${rejected.id}`).then((r) => r.json())
  ).data;
  check(
    stored.status === 'Rejected' &&
      stored.rejectionReason === 'Falta el detalle de la actividad corporativa.',
    'UI rejection persisted with trimmed reason',
  );
  const external = await page.request.patch(
    `${apiBaseUrl}/api/reimbursements/${conflict.id}/approve`,
  );
  check(external.status() === 200, 'Concurrent reviewer resolved fixture');
  await row(conflict.id).getByRole('button', { name: 'Aprobar', exact: true }).click();
  await page.getByRole('status').filter({ hasText: 'Esta solicitud ya fue resuelta.' }).waitFor();
  await waitLoaded();
  check((await row(conflict.id).count()) === 0, '409 displays message and refreshes stale list');
  await select('Aprobado');
  check(await row(approved.id).isVisible(), 'Approved filter');
  await select('Rechazado');
  check(
    await row(rejected.id)
      .getByText('Falta el detalle de la actividad corporativa.', { exact: false })
      .isVisible(),
    'Rejected filter and reason',
  );
  const allRequest = page.waitForRequest(
    (request) => request.method() === 'GET' && request.url().includes('/api/reimbursements'),
  );
  await select('Todos los estados');
  check(
    !new URL((await allRequest).url()).searchParams.has('status'),
    'All filter omits status query',
  );
  await page.route('**/api/reimbursements*', (route) => route.abort('connectionfailed'));
  await page.getByRole('button', { name: 'Actualizar', exact: false }).click();
  await page.getByRole('alert').waitFor();
  check(
    await page.getByRole('button', { name: 'Reintentar consulta' }).isVisible(),
    'Network failure exposes retry',
  );
  await page.unroute('**/api/reimbursements*');
  await page.getByRole('button', { name: 'Reintentar consulta' }).click();
  await waitLoaded();
  check((await page.locator('.error-panel').count()) === 0, 'Network recovery succeeds');
  await page.route('**/api/reimbursements*', (route) =>
    route.fulfill({
      json: {
        success: true,
        message: 'Operación completada.',
        data: {},
        errors: [],
        traceId: 'invalid-data-test',
      },
    }),
  );
  await select('Pendiente');
  check(
    await page.getByRole('alert').isVisible(),
    'Malformed list rejected instead of empty success',
  );
  await page.unroute('**/api/reimbursements*');
  await page.getByRole('button', { name: 'Reintentar consulta' }).click();
  await waitLoaded();
  await page.route('**/api/reimbursements*', async (route) => {
    const response = await route.fetch();
    if (new URL(route.request().url()).searchParams.get('status') === 'Approved')
      await new Promise((resolve) => setTimeout(resolve, 500));
    await route.fulfill({ response });
  });
  await filter.selectOption({ label: 'Aprobado' });
  await filter.selectOption({ label: 'Rechazado' });
  await waitLoaded();
  await page.waitForTimeout(700);
  check(
    (await row(rejected.id).isVisible()) && (await row(approved.id).count()) === 0,
    'Latest filter wins when responses arrive out of order',
  );
  await page.unroute('**/api/reimbursements*');
  await page.route('**/api/reimbursements*', (route) =>
    route.fulfill({
      json: {
        success: true,
        message: 'Operación completada.',
        data: [],
        errors: [],
        traceId: 'empty-state-test',
      },
    }),
  );
  await select('Pendiente');
  check(
    await page
      .getByRole('heading', { name: 'No hay solicitudes pendientes', exact: true })
      .isVisible(),
    'Empty state is actionable',
  );
  await page.unroute('**/api/reimbursements*');
  await page.getByRole('button', { name: 'Actualizar', exact: false }).click();
  await waitLoaded();
  return {
    results,
    fixtureIds: [approved.id, rejected.id, conflict.id, maximum.id],
    employeeName: name,
    artifacts,
  };
}
