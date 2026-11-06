# Consware · Reembolso de gastos

Sistema de solicitudes de reembolso con API ASP.NET, persistencia SQL Server, aplicación Flutter para el empleado y panel Angular para el aprobador.

## Estado de la entrega

La API cuenta con aceptación HTTP y persistencia verificadas. Flutter está comprobado contra esa API en navegador y Android, con selector de estado y diez pruebas automatizadas aprobadas. Angular permite filtrar, aprobar y rechazar, con aceptación funcional automatizada; su presentación está en renovación con PrimeNG. Los resultados comprobados están en [docs/test-results.md](docs/test-results.md).

## Reglas de negocio

- Hasta **$500.000 COP inclusive**, la solicitud se aprueba al crearla.
- Por encima de ese monto queda pendiente de decisión.
- Un rechazo necesita un motivo escrito.
- Una decisión final no puede modificarse, incluso con solicitudes simultáneas.

## Arquitectura

Un backend .NET 8 con controllers/DTOs, servicio de negocio, mapper inyectado y EF Core 8. El estado se representa con `ReimbursementStatus` y se almacena como texto en SQL Server. Las excepciones de validación, inexistencia y conflicto se traducen de forma centralizada a HTTP. La base es `ConswareReimbursements`. Flutter registra y consulta gastos del empleado; Angular permite al aprobador decidir.

El contrato compartido está en [docs/api-contract.md](docs/api-contract.md): todas las respuestas de aplicación tienen `success`, `message`, `data`, `errors` y `traceId`, conservando los códigos HTTP correctos. El código y los contratos usan inglés; los mensajes para el usuario usan español.

## Requisitos

- Windows con .NET SDK 8 y SQL Server accesible. En el equipo de desarrollo se comprobó `Server=localhost` con autenticación integrada y permiso para crear la base.
- Node.js 22.12; Angular utiliza CLI local 21, independiente del CLI global.
- Flutter 3.47.9 con Dart 3.13.7, versiones utilizadas para compilar y comprobar la app. Para Android se requiere además JDK 17, SDK Android y emulador o dispositivo; se verificó un emulador API 35.
- PowerShell 7.5 o superior para los scripts de aceptación (se utilizó 7.6.7).

## Preparar y ejecutar la API

Desde la raíz del repositorio:

```powershell
cd backend
dotnet tool restore
dotnet restore Consware.Reimbursements.Api
dotnet ef database update --project Consware.Reimbursements.Api
cd ..
pwsh -File scripts/start.ps1 api
```

La migración crea la base y las tablas. Para otro servidor, configurar la conexión antes de migrar y ejecutar:

```powershell
$env:ConnectionStrings__Reimbursements = 'Server=TU_SERVIDOR;Database=ConswareReimbursements;Integrated Security=True;TrustServerCertificate=True'
```

Se necesita permiso para crear la base o una base vacía ya preparada. `TrustServerCertificate=True` corresponde al entorno de desarrollo. Swagger está disponible en `http://localhost:5000/swagger`.

## Comprobación de API

Con la API encendida:

```powershell
pwsh -File scripts/verify-api.ps1
```

El script termina con código distinto de cero si falla una comprobación. Genera registros identificables y conserva un snapshot temporal para comprobar durabilidad mediante `-VerifyPersistence` después de reiniciar la API. Los datos persisten en SQL Server; no se usa un proveedor en memoria.

## Direcciones de desarrollo

| Componente | Dirección |
|---|---|
| API | http://localhost:5000 |
| Flutter Web | http://localhost:8080 |
| API desde emulador Android | http://10.0.2.2:5000 |
| Angular | http://localhost:4200 |

## Ejecutar Flutter

Con Flutter instalado y disponible en PATH, preparar las dependencias y arrancar cada destino en una terminal separada:

```powershell
cd mobile
flutter pub get
cd ..
pwsh -File scripts/start.ps1 mobile-web
```

Para Android, iniciar un emulador, consultar su identificador mediante `flutter devices` y ejecutar:

```powershell
pwsh -File scripts/start.ps1 mobile-android -Device emulator-5554
```

La URL de API es configurable con `-ApiBaseUrl`. En navegador se utiliza `http://localhost:5000`; el emulador Android accede al equipo mediante `http://10.0.2.2:5000`. El script admite `-FlutterPath` si Flutter no está en PATH. La configuración de HTTP sin cifrar se limita al desarrollo Android.

Para verificar Flutter:

```powershell
cd mobile
flutter analyze
flutter test
```

## Ejecutar Angular

Con la API iniciada, instalar dependencias y arrancar el panel en otra terminal:

```powershell
cd web
npm ci
cd ..
pwsh -File scripts/start.ps1 web
```

El panel abre en `http://localhost:4200`. La URL de API se configura en `web/src/environments/environment.ts`. El filtro comienza en Pendientes y las decisiones se envían a la API real.

```powershell
cd web
npm run build

# Requiere API, Angular en el puerto 4200 y Microsoft Edge instalado
npm test
```

La suite de Playwright crea registros de prueba identificables y conserva los datos. Comprueba decisiones, conflictos, estados de recuperación y tamaños de pantalla. La salida de producción se genera en `web/dist/consware-approvals/browser/`. Más detalle en [web/README.md](web/README.md).

## Decisiones y límites

Se conserva una arquitectura pequeña y una identidad fija `Empleado Demo`, sin autenticación, adjuntos, microservicios ni despliegue. La interfaz usa azules claros y superficies de cristal, controles táctiles y anchos máximos según la pantalla. Un sistema de producción necesitaría autorización, auditoría, comprobantes y gestión real de empleados.

La API usa `decimal(18,2)`. Angular conserva el rango completo sin convertir los importes a números binarios de JavaScript; Flutter limita el formulario a 9999999999.99 COP para preservar los centavos. Ambos clientes presentan los estados en español y usan los valores del enum en el contrato.

Las direcciones, CORS y HTTP sin cifrar están configurados para desarrollo local. En un teléfono físico se debe configurar una URL de API accesible desde su red. Como mejoras posteriores quedan la autenticación por roles, paginación en servidor y un registro de auditoría; no forman parte de esta entrega.

## Uso de IA

Se utilizaron Codex y Antigravity como apoyo para definir la arquitectura y los contratos, implementar componentes, revisar la integración y ejecutar verificaciones. Las reglas se contrastaron con el enunciado y las pruebas se ejecutaron contra la API y SQL Server reales. Las decisiones técnicas y los resultados comprobados están documentados en este repositorio.
