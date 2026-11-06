# Consware · Reembolso de gastos

Sistema de solicitudes de reembolso con API ASP.NET, persistencia SQL Server, aplicación Flutter para el empleado y panel Angular para el aprobador.

## Estado de la entrega

API implementada y verificada: 50/50 casos de aceptación independiente aprobados, además de las verificaciones del backend y persistencia tras reinicio. Flutter está en implementación; Angular espera la aceptación de Flutter. Los resultados comprobados están en `docs/test-results.md`.

## Reglas de negocio

- Hasta **$500.000 COP inclusive**, la solicitud se aprueba al crearla.
- Por encima de ese monto queda pendiente de decisión.
- Un rechazo necesita un motivo escrito.
- Una decisión final no puede modificarse, incluso con solicitudes simultáneas.

## Arquitectura

Un backend .NET 8 con controllers/DTOs, servicio de negocio y EF Core 8. SQL Server guarda los datos en una base nueva `ConswareReimbursements`. La API es la autoridad de las reglas. Flutter permite registrar y consultar gastos del empleado; Angular permite al aprobador decidir.

El contrato compartido está en [docs/api-contract.md](docs/api-contract.md): todas las respuestas de aplicación tienen `success`, `message`, `data`, `errors` y `traceId`, conservando los códigos HTTP correctos. El código y los contratos usan inglés; los mensajes para el usuario usan español.

## Requisitos

- Windows con .NET SDK 8 y SQL Server accesible. En el equipo de desarrollo se comprobó `Server=localhost` con autenticación integrada y permiso para crear la base.
- Node.js 22.12; Angular utiliza CLI local 21, independiente del CLI global.
- Flutter estable; para Android se requiere además JDK, SDK Android y emulador o dispositivo.
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

## Verificación y herramientas de agentes

Se instalaron globalmente `@playwright/mcp@0.0.84` y `@cocaxcode/api-testing-mcp@0.13.4`, y se registraron en Codex, Antigravity y OpenCode. No son dependencias de ejecución del producto.

`python scripts/verify-mcp.py` comprueba inicialización y catálogo MCP y abre un navegador Edge aislado. Con la API iniciada: `python scripts/verify-mcp.py --api-url http://127.0.0.1:5000/api/reimbursements`. Usar IPv4 explícita para este cliente Node: en el equipo de desarrollo `localhost` resolvió a IPv6 mientras la API escuchaba en IPv4. Las evidencias se guardan localmente en `artifacts/`, fuera de Git. La prueba web no sustituye ejecutar Flutter en Android.

## Decisiones y límites

Se conserva una arquitectura pequeña y una identidad fija `Empleado Demo`, sin autenticación, adjuntos, microservicios ni despliegue. El foco es un flujo real, mensajes de error claros y una interfaz adaptable en azul y cristal. Un sistema de producción necesitaría autorización, auditoría, comprobantes y gestión real de empleados.

## Uso de IA

Codex coordina la arquitectura, el contrato, las instrucciones y las verificaciones, y tiene trabajadores para backend y aceptación/panel web. Antigravity prepara Flutter/Android y desarrollará la aplicación del empleado. Se intentó utilizar OpenCode, pero su cuota gratuita estaba agotada; el usuario autorizó sustituirlo por Codex. El usuario autorizó iniciar Antigravity con `--dangerously-skip-permissions` para evitar interrupciones de permisos.

Las herramientas ayudan a generar y revisar el código. Los resultados de pruebas se documentarán solo después de ejecutarse; las decisiones deberán poder explicarse y modificarse durante la entrevista.
