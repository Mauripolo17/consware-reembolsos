# Resultados de verificación

Fecha: 6 de noviembre de 2026. Las comprobaciones de integración se ejecutan contra la API real y SQL Server, sin sustituir la persistencia por una lista en memoria.

## API y persistencia

`pwsh -File scripts/verify-api.ps1`: **50 casos aprobados, 0 fallos**. La ejecución posterior a la incorporación de enum, mapper inyectado y excepciones centralizadas también aprobó 50/50; los datos anteriores se conservaron, con otras 12/12 comprobaciones de durabilidad. EF no detectó cambios de esquema pendientes: el enum mantiene el almacenamiento de texto existente.

| Área | Escenarios comprobados |
|---|---|
| Aprobación automática | 499999 y 500000 aprobados; 500000.01 y 500001 pendientes. |
| Importes | Positivo mínimo, máximo decimal(18,2), cero, negativos, ausencia/null, tipo incorrecto, exceso de precisión y desbordamiento. |
| Textos | Campos ausentes, vacíos, espacios, longitudes máximas y normalización. |
| HTTP y contrato | Envelope uniforme en éxito/error; JSON malformado, filtro inválido, ID inválido/inexistente, rutas desconocidas, 405 y 415. |
| Consultas | Orden descendente, listas vacías, filtro por empleado completo, estado y combinación de ambos. |
| Decisiones | Aprobar, rechazar con motivo, motivo inválido e inmutabilidad posterior. |
| Concurrencia | Dos decisiones simultáneas: exactamente un HTTP 200 y un 409; el registro conserva la decisión ganadora. |

Después de un reinicio real de la API, `pwsh -File scripts/verify-api.ps1 -VerifyPersistence` aprobó **12/12 registros conservados**. El script guarda un snapshot temporal y requiere coordinar el reinicio antes de usar esa opción.

Se comprobó un fallo real de conexión SQL en un proceso de prueba separado: HTTP 500, mensaje seguro en español, código `INTERNAL_ERROR`, `traceId` y el mismo envelope; sin stack trace ni detalles SQL en la respuesta. El proceso temporal se retiró sin detener SQL Server.

Para comparar importes extremos, el verificador usa `System.Text.Json.GetDecimal()`; las fechas se conservan como texto. Las comparaciones usan valores semánticos, no diferencias irrelevantes como `500001` frente a `500001.00`.

## Flutter

La aplicación web se ejecutó contra la API real. Se revisaron capturas de interfaz cargada a 360, 768 y 1440 píxeles: contenido centrado y acotado, navegación adaptable y ausencia de desbordamiento horizontal del documento. Se comprobó creación, listado, filtros y presentación del motivo de rechazo.

`flutter analyze`: sin incidencias. `flutter test`: **10/10 pruebas aprobadas**, incluidas validación de importes y límite seguro, agrupación ambigua de miles, respuestas HTTP inconsistentes, carga fuera de orden, creación/listado, rechazo y recuperación de errores.

Se construyó el APK debug y se ejecutó en un emulador Android API 35 x86_64 con aceleración WHPX. La app cargó datos reales mediante `http://10.0.2.2:5000`, creó una solicitud de 315000 COP y actualizó su listado. Se inspeccionó además una captura nativa con el selector de estado ya incorporado. La verificación web incluyó creación real de una solicitud de 245000 COP.

El selector de filtro usa el enum del modelo y admite Todas, Pendientes, Aprobadas y Rechazadas. El estado de creación lo decide la API. La interfaz limita el importe a 9999999999.99 COP para conservar la precisión de centavos durante la conversión numérica del cliente; la API admite el rango decimal(18,2) completo.

## Angular

Se compiló la aplicación en modo producción y se ejecutó la suite de aceptación reproducible mediante `cd web` y `npm test`: **una prueba integrada con 31 comprobaciones aprobadas**, contra la API y SQL Server reales. Incluye aprobación, rechazo con motivo obligatorio, conflicto 409, bloqueo del doble envío, filtros, respuestas fuera de orden, carga, vacío, fallos de red y recuperación. Los importes extremos se muestran sin pérdida de centavos.

Se revisaron listado y diálogo a 360, 768 y 1440 píxeles, incluida una razón larga de 500 caracteres. Los interceptores de red se usan únicamente para provocar latencia y fallos controlados. La revisión visual con PrimeNG y la comprobación integral entre ambos clientes siguen en curso; estos resultados corresponden a la versión funcional anterior al rediseño.

## Reproducción

```powershell
# API iniciada en otra terminal
pwsh -File scripts/verify-api.ps1

# Después de reiniciar esa API, conservando el snapshot de la prueba anterior
pwsh -File scripts/verify-api.ps1 -VerifyPersistence
```

Los registros del script utilizan identificadores de empleado únicos. El script no elimina datos ni reinicia procesos. Las comprobaciones pendientes no se contabilizan como aprobadas.
