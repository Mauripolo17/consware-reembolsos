# Resultados de verificación

Fecha: 6 de noviembre de 2026. Las comprobaciones de integración se ejecutan contra la API real y SQL Server, sin sustituir la persistencia por una lista en memoria.

## API y persistencia

`pwsh -File scripts/verify-api.ps1`: **50 casos aprobados, 0 fallos**. La ejecución posterior a la reorganización de contratos y servicios también aprobó 50/50.

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

El entorno Android cuenta con un emulador API 35 x86_64 arrancado y aceleración WHPX disponible. La comprobación funcional nativa y la verificación final del selector de estado se actualizarán al terminar su ejecución.

## Reproducción

```powershell
# API iniciada en otra terminal
pwsh -File scripts/verify-api.ps1

# Después de reiniciar esa API, conservando el snapshot de la prueba anterior
pwsh -File scripts/verify-api.ps1 -VerifyPersistence
```

Los registros del script utilizan identificadores de empleado únicos. El script no elimina datos ni reinicia procesos. Las comprobaciones pendientes no se contabilizan como aprobadas.
