# Panel de aprobaciones

Aplicación Angular 21 standalone para consultar y resolver solicitudes de reembolso. Utiliza la API real; el estado inicial del filtro es Pendiente. Las decisiones son definitivas y el backend valida las transiciones.

Requisitos: Node.js 22.12 o superior compatible con Angular 21, npm y API disponible en `http://localhost:5000`. La URL se configura en `src/environments/environment.ts`. Todos los comandos utilizan el CLI local del proyecto.

Desde esta carpeta:

```powershell
npm ci
npm start -- --host localhost --port 4200
```

Compilación de producción:

```powershell
npm run build
```

La salida queda en `dist/consware-approvals/browser/`. El servidor que la publique debe resolver las rutas de la aplicación hacia `index.html`.

Pruebas de aceptación con Microsoft Edge instalado, API conectada a SQL Server y aplicación ya iniciada en el puerto 4200:

```powershell
npm test
```

La suite crea cuatro registros identificables `Angular-<timestamp>` y conserva los datos. Comprueba aprobación/rechazo reales, conflicto 409, filtros, protección contra doble envío, precisión monetaria y diseños a 360/768/1440px. Usa interceptores únicamente para inducir fallos de red, respuestas inválidas, estado vacío y latencia. Las capturas y resultados temporales se guardan en `artifacts/`, excluida de Git.

El mapper inyectable valida los DTO antes de presentar datos. Los importes se leen sin pérdida de precisión para conservar el rango decimal(18,2) de la API. El servicio HTTP centraliza envelope, errores y timeout; no reintenta decisiones automáticamente.
