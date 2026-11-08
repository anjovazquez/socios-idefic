# DESIGN.md — Sistema de diseño de Socios

Fuente de verdad visual para `lib/presentation/`. Toda pantalla nueva o
modificada debe seguirlo (Gate 2.1 de `socios_harness/QUALITY_GATES.md`).
Si falta un patrón, se añade aquí en el mismo cambio.

## 1. Principios y tono de voz

- **Cada club se siente suyo.** La app es una sola, pero el club activo tiñe
  cabecera, navegación, acciones principales, carnet y recibos (§20).
- **Claridad antes que decoración.** Pantallas de una tarea, una acción
  principal visible.
- **Tono:** español neutro, segunda persona («Tu carnet», «Elige tu club»),
  frases cortas, sin jerga técnica («No hemos podido conectar», nunca
  «Error 500»). Los errores dicen qué pasa y qué hacer.
- **Nada de culpa.** «Tu club todavía no te ha dado de alta con ese email»,
  no «Usuario no autorizado».
- Sin emojis en la interfaz.

## 2. Color

### 2.1 Color del club

| Token | Origen | Uso |
|---|---|---|
| `primary` | `clubs.primary_color` (exacto) | AppBar, botones principales, avatar sin logo |
| `onPrimary` | `readableOn(primary)` | Texto/iconos sobre `primary` |
| `secondary` | `clubs.secondary_color` (opcional) | Acentos: chips, insignias |
| `onSecondary` | `readableOn(secondary)` | Texto sobre `secondary` |
| resto del `ColorScheme` | `ColorScheme.fromSeed(primary)` | Superficies, contenedores, error |

- El tema se construye siempre con `buildClubTheme()`
  (`lib/presentation/theme/club_theme.dart`). Nunca `Colors.*` ni hex sueltos
  en widgets: se usa `Theme.of(context).colorScheme`.
- **Contraste:** el texto sobre colores del club debe alcanzar WCAG AA
  (`BrandTokens.minContrast = 4.5`). `readableOn()` elige claro u oscuro
  según el mayor contraste; un color muy claro (p. ej. `#FFF59D`) lleva texto
  oscuro.
- Sin club activo (login, selector) se usa `BrandTokens.defaultPrimary`
  (`#0B3D91`).
- Paleta rápida en Configuración: `BrandTokens.presetColors`.

### 2.2 Estados (semánticos)

- Validación del carnet (pantalla pública del QR): `BrandTokens.valid`
  (verde, «SOCIO ACTIVO») y `BrandTokens.invalid` (rojo, «NO VÁLIDO…» /
  «CARNET NO ENCONTRADO»), siempre con icono y texto en mayúsculas.
- Socio por temporada: `SeasonMembershipChip` (Socio, Pendiente de pago,
  No renovado, Cancelado).

Para el resto, hasta los pagos (VS-017) solo se usa
`colorScheme.error` para errores. Los nuevos estados (activo, pendiente,
fallido, cancelado) se añadirán aquí como tokens semánticos, siempre con
icono + texto, nunca solo color.

### 2.3 Importes y fechas

- Importes siempre en céntimos en datos y formateados con `formatCents`
  (`presentation/format/money.dart`): `50,00 €`, `1.250,50 €`. Los campos de
  importe aceptan `50`, `50,5`, `50.50` o `1.250,00` (`parseEurosToCents`).
- Fechas `dd/MM/yyyy` (`formatDate`).
- Estados de temporada con icono + texto: Activa, Preparada, Cerrada.

## 3. Tipografía

- Siempre `Theme.of(context).textTheme.*` (Material 3). Nada de
  `TextStyle(fontSize: …)` literal; solo se permite `copyWith(color: …)`
  para aplicar un token de color.
- Jerarquía: `headlineMedium` título de pantalla de entrada, `titleLarge` /
  `titleMedium` secciones, `bodyMedium` texto, `bodySmall` notas.

## 4. Espaciado y layout

- Escala: 4 · 8 · 12 · 16 · 24 · 32.
- Márgenes de pantalla: 16 (listas) o 24 (formularios de entrada).
- Formularios de una columna con ancho máximo 400 en web.
- Objetivos táctiles ≥ 48 px.

## 5. Navegación

- Socio (móvil): navegación inferior Inicio · Mi carnet · Mis ventajas ·
  Mi suscripción · Mis datos (VS-032).
- Administración (web): secciones del §16 del documento funcional.
- Cabecera (`AppBar`) con el color del club; acciones a la derecha:
  Configuración (solo admin), Plataforma (solo superadmin), Cambiar de club
  (si hay varios), Cerrar sesión.
- Subpantallas cuelgan de la ruta del área (`/club/settings`); el botón atrás
  vuelve al área.

## 6. Componentes compartidos

| Componente | Archivo | Uso |
|---|---|---|
| `ClubAvatar` | `presentation/club/club_avatar.dart` | Logo del club o iniciales sobre su color; con `Semantics` «Logo de …» |
| `MembershipCardView` | `presentation/card/membership_card_view.dart` | Carnet: proporción de tarjeta (1,586), degradado del color principal a su versión oscura, franja del color secundario, logo, foto, nombre, nº, temporada y hueco blanco para el QR. Si no está activo se muestra atenuado (45 %) con un aviso debajo |
| `buildClubTheme` / `readableOn` | `presentation/theme/club_theme.dart` | Tema y contraste |
| `ClubFormDialog` | `presentation/platform/club_form_dialog.dart` | Patrón de formulario en diálogo: error inline, botón principal a la derecha |
| `startFeePayment` | `presentation/payment/how_to_pay_sheet.dart` | Hoja «Cómo pagar tu cuota de X €» con las instrucciones del club (carnet y Mi suscripción) |
| `PaymentStatusChip` | `presentation/payment/payment_labels.dart` | Estado del pago con icono + texto: Pagado, Pendiente, Fallido, Anulado |
| Recibo PDF | `presentation/receipt/pdf_receipt_renderer.dart` | A4: cabecera del color del club (texto con `readableOn`), logo si existe, nombre y «Recibo de pago», nº `CODIGO-0001`; filas etiqueta/valor; importe en negrita; pie legal. Fuente Roboto incluida |
| Pago online | `presentation/payment/my_subscription_page.dart`, `online_payments_section.dart` | Con cuota pendiente y club con Stripe: botón principal «Pagar ahora con tarjeta o domiciliación» y secundario «Otras formas de pago». Al volver del Checkout, aviso en `secondaryContainer` («Estamos confirmando tu pago…» / «No se ha completado el pago…»). En Configuración, «Pagos online» con estado (icono + frase) y «Conectar con Stripe» / «Completar verificación» / «Comprobar estado» |
| `PostStatusChip` | `presentation/blog/blog_messages.dart` | Estado de una noticia con icono + texto: Publicada, Programada, Borrador, Archivada |
| Editor de noticia | `presentation/blog/post_editor_page.dart` | Título (140), texto (párrafos), imagen opcional con vista previa, `SegmentedButton` Ahora/Programar con fecha y hora, «Guardar borrador» + acción principal «Publicar»/«Programar»; error inline |
| `PostCard` / `PostImage` | `presentation/blog/post_widgets.dart` | Noticia en Inicio: imagen (URL firmada; nada si falla), fecha, título y extracto (primer párrafo, 160 caracteres); detalle con fecha larga y párrafos |
| Estado de mensaje (`_MessagePage`) | `presentation/session/session_status_pages.dart` | Pantalla vacía/error: título, explicación, acción |

Patrones:

- **Estado vacío:** título corto + una frase de qué hacer + acción si existe.
- **Error de formulario:** debajo de los campos, en `colorScheme.error`, sin
  cerrar el formulario.
- **Confirmación destructiva** (desactivar, dar de baja): diálogo con
  consecuencia explicada («No se borra ningún dato») y botón con el verbo.
- **Confirmación de éxito:** `SnackBar` con frase corta («Cambios guardados»). Un aviso nuevo
  sustituye al anterior (`hideCurrentSnackBar()` antes de `showSnackBar`), para
  que no se acumulen en cola.
- **Listas largas de gestión:** buscador con espera de 300 ms, filtros con
  `ChoiceChip`, total visible («N socios»), «Ver más» al final y ficha en
  `BottomSheet` con las acciones del elemento.
- **Flujo por pasos** (primer acceso): «Paso N de M» + `LinearProgressIndicator`,
  un título por paso, el botón principal «Continuar» y la última acción con
  el verbo final («Aceptar y entrar»). Los datos ya conocidos se precargan.
  Los textos legales van en un contenedor con scroll y una casilla explícita.

## 7. Identidad del club en pantallas

| Pantalla | Qué muestra |
|---|---|
| Selector de club | `ClubAvatar` (logo/iniciales), nombre, nº de socio |
| Portada del club (Inicio) | Cabecera con color del club, `ClubAvatar` grande, Mi carnet / Mi suscripción y «Noticias» del club (vacío: «Aquí verás las novedades de {club}») |
| Configuración | Vista previa en vivo de cabecera, avatar, botón principal y acento |
| Carnet (VS-015), recibos (VS-019, PDF), emails (VS-006/032) | Logo y colores del club |

Assets del club en el bucket público `club-assets/<club_id>/` (PNG, JPG o
WebP, ≤ 2 MB). El logo se muestra con `BoxFit.contain` sobre `surface`.
