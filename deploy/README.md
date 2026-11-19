# Archivos para alojar en el dominio web (NO van dentro de la app)

Plantillas de `.well-known` para que Android App Links e iOS Universal Links
verifiquen la app (ADR-001, CR-001). **Los valores `REEMPLAZAR_*` son datos que
IPR debe entregar** y que este repositorio no inventa:

| Dato | Quién lo entrega | Decisión relacionada |
|---|---|---|
| `applicationId` definitivo y `bundleId` | Gerencia / TI | D-14 |
| Huella SHA-256 de la clave de firma de Google Play | Quien administre la consola | D-14 |
| Team ID de Apple | Quien administre la cuenta de desarrollador | D-14 |

Se publican en `https://<deepLinkHost>/.well-known/assetlinks.json` y
`https://<deepLinkHost>/.well-known/apple-app-site-association`, sin redirecciones
y con `Content-Type: application/json`. El responsable técnico del sitio debe
alojarlos (condición C1/C2 de ADR-001). La app solo acepta `/app/pedido`; la
verdad del pago siempre se consulta al servidor (CR-002).
