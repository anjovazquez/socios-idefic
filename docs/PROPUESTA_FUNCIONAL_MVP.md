# **Documento funcional MVP**

## **Plataforma de gestión de socios para clubes de baloncesto amateur**

## **1. Objetivo**

Desarrollar una plataforma web y aplicación para clubes de baloncesto
amateur que permita gestionar socios, temporadas, cuotas, pagos,
patrocinadores, ventajas y comunicaciones internas.

Los principales objetivos del producto son:

- Facilitar a los socios la renovación y pago de su cuota.

- Permitir que cada socio disponga de un carnet digital.

- Automatizar, en la medida de lo posible, la renovación entre
  > temporadas.

- Crear un espacio privado de comunicación entre el club y sus socios.

- Dar visibilidad a los patrocinadores dentro de la comunidad de socios.

- Centralizar la gestión de distintos clubes en una única plataforma.

# **2. Modelo general de la plataforma**

La plataforma será multi-club.

Cada club dispondrá de:

- identidad visual propia;

- nombre;

- logotipo;

- código identificativo;

- socios;

- patrocinadores;

- temporadas;

- publicaciones;

- ventajas;

- cuotas y pagos.

La gestión técnica será centralizada.

Un mismo usuario podrá pertenecer a varios clubes utilizando la misma
cuenta de acceso.

Ejemplo:

Usuario: usuario@email.com

- Club A

- Club B

- Club C

Tras iniciar sesión, el usuario podrá seleccionar el club al que desea
acceder.

En dispositivos móviles deberá poder identificar fácilmente cada club
mediante su nombre, logotipo e identidad visual.

Como evolución futura podrá estudiarse la instalación de accesos
independientes tipo PWA para cada club.

# **3. Roles**

La aplicación tendrá inicialmente tres roles.

## **3.1. Administrador principal**

Administrador global de la plataforma.

Funciones:

- alta de clubes;

- modificación de clubes;

- desactivación de clubes;

- consulta de clubes;

- acceso a cualquier club;

- actuar como administrador de cualquier club.

## **3.2. Administrador de club**

Responsable de gestionar un club concreto.

Inicialmente existirá un único administrador por club.

Funciones principales:

- gestión de socios;

- gestión de temporadas;

- gestión de cuotas;

- gestión de pagos;

- gestión de patrocinadores;

- publicación de contenido;

- publicación de ventajas;

- consulta y descarga de recibos.

## **3.3. Socio**

Usuario final de la aplicación.

Solo podrá acceder a aquellos clubes en los que haya sido dado de alta
como socio.

No existe registro público de usuarios.

# **4. Acceso y autenticación**

## **RF-001. Inicio de sesión**

El usuario podrá identificarse mediante:

- email y contraseña;

- cuenta de Google.

No existirá un formulario público de registro.

## **RF-002. Alta de socio**

El alta inicial será realizada por el administrador del club.

Datos mínimos requeridos:

- nombre;

- email.

Una vez creado, el sistema enviará automáticamente una invitación por
email.

## **RF-003. Invitación**

El email de invitación incluirá un enlace para activar la cuenta.

En el primer acceso, el socio deberá:

1.  crear su contraseña si no utiliza Google;

2.  completar sus datos personales;

3.  aceptar las condiciones necesarias para utilizar el servicio.

## **RF-004. Usuario existente**

Si el email ya corresponde a un usuario de la plataforma, no se creará
una nueva cuenta.

El nuevo club quedará asociado a su usuario existente.

Ejemplo:

usuario@email.com pertenece inicialmente al Club A.

El administrador del Club B da de alta:

usuario@email.com

El usuario verá posteriormente:

- Club A

- Club B

utilizando las mismas credenciales.

# **5. Perfil del socio**

## **RF-005. Mis datos**

El socio podrá consultar y modificar:

- nombre;

- apellidos;

- fotografía;

- teléfono;

- fecha de nacimiento.

El email se utilizará como identificador principal de acceso.

## **RF-006. Número de socio**

Cada socio tendrá un número dentro de cada club.

El número:

- será generado automáticamente;

- será independiente para cada club;

- podrá ser modificado por el administrador del club;

- no podrá ser modificado por el socio.

Un mismo usuario puede, por tanto, tener diferentes números de socio en
diferentes clubes.

# **6. Temporadas**

Las temporadas serán uno de los elementos centrales de la aplicación.

Ejemplo:

2026/2027  
2027/2028  
2028/2029

## **RF-007. Gestión de temporadas**

El administrador podrá:

- crear una temporada;

- establecerla como activa;

- consultar temporadas anteriores.

Cada club tendrá una única temporada activa.

## **RF-008. Cuota de temporada**

Al activar una temporada, el administrador establecerá la cuota
ordinaria.

Ejemplo:

Temporada: 2027/2028  
Cuota: 50 €

Esta será la cuota propuesta por defecto para todos los socios.

# **7. Socios y temporadas**

La pertenencia a un club no implica automáticamente pertenecer a todas
sus temporadas.

Debe existir una relación:

SOCIO + CLUB + TEMPORADA

De esta forma se conserva el histórico.

Ejemplo:

| **Temporada** | **Estado**  |
|---------------|-------------|
| 2025/2026     | Socio       |
| 2026/2027     | Socio       |
| 2027/2028     | No renovado |

## **RF-009. Renovación masiva**

Al crear una nueva temporada, el administrador podrá iniciar la
renovación de los socios de la temporada anterior.

El sistema mostrará todos los socios renovables.

El administrador podrá:

- renovar todos;

- excluir determinados socios;

- modificar individualmente el importe antes de enviar la renovación.

## **RF-010. Cuotas personalizadas**

Aunque exista una cuota general de temporada, el administrador podrá
modificar el importe correspondiente a un socio.

Ejemplos:

Cuota general: 50 €

Socio A → 50 €  
Socio B → 25 €  
Socio C → 0 €

Esto permitirá gestionar:

- descuentos;

- exenciones;

- socios honoríficos;

- situaciones especiales.

# **8. Suscripción y renovación**

## **RF-011. Mi suscripción**

El socio dispondrá de un apartado denominado:

**Mi suscripción**

Desde él podrá consultar:

- temporada actual;

- importe de la cuota;

- estado;

- método de pago;

- próximos cargos;

- histórico de pagos;

- recibos.

## **RF-012. Renovación automática**

El sistema deberá favorecer que la renovación entre temporadas requiera
la mínima intervención posible por parte del socio.

Cuando exista un método de pago que permita cobros recurrentes, el
usuario podrá mantenerlo asociado para futuras renovaciones.

## **RF-013. Aviso previo de renovación**

Antes de realizar una renovación automática, el socio deberá recibir una
comunicación indicando:

- nueva temporada;

- importe que se cobrará;

- fecha prevista de cobro;

- posibilidad de cancelar la renovación.

Ejemplo:

> Tu suscripción al Club X se renovará para la temporada 2027/2028 por
> un importe de 50 €. El cargo se realizará el 1 de septiembre. Puedes
> cancelar la renovación antes de esa fecha.

## **RF-014. Cancelación**

Antes de producirse el cobro, el socio podrá cancelar la renovación.

La cancelación impedirá el cargo correspondiente a la nueva temporada.

# **9. Pagos**

La solución de pago concreta deberá seleccionarse buscando
prioritariamente:

1.  simplicidad para el socio;

2.  facilidad de integración;

3.  posibilidad de renovación automática;

4.  bajo coste;

5.  mínima gestión administrativa para el club.

La integración concreta con tarjeta, domiciliación bancaria, Bizum u
otro proveedor quedará desacoplada del resto del sistema.

## **RF-015. Estado de los pagos**

Los pagos podrán disponer, como mínimo, de los siguientes estados:

- pendiente;

- pagado;

- fallido;

- cancelado.

## **RF-016. Histórico de pagos**

El socio podrá consultar sus pagos anteriores.

Cada registro mostrará al menos:

- temporada;

- concepto;

- importe;

- fecha;

- estado.

## **RF-017. Recibo**

Para cada pago completado se generará un recibo descargable.

El recibo incluirá como mínimo:

- datos del club;

- nombre del socio;

- número de socio;

- temporada;

- concepto;

- importe;

- fecha del pago;

- identificador del pago.

No será necesario generar factura en el MVP.

## **RF-018. Gestión de pagos por el administrador**

El administrador podrá consultar los pagos correspondientes a su club.

Podrá filtrar, como mínimo, por:

- temporada;

- socio;

- estado del pago.

También podrá descargar los recibos.

# **10. Carnet digital**

## **RF-019. Mi carnet**

Cada socio activo dispondrá de un carnet digital.

El carnet deberá tener un diseño visual atractivo y adaptado a la
identidad del club.

Mostrará como mínimo:

- logotipo del club;

- fotografía;

- nombre y apellidos;

- número de socio;

- temporada;

- código QR.

## **RF-020. Código QR**

El QR identificará el carnet mediante una URL o código único no
predecible.

Al escanearlo se mostrará una pantalla simplificada de validación.

Información visible:

- club;

- fotografía;

- nombre y apellidos;

- número de socio;

- temporada;

- estado del carnet.

Ejemplo:

**SOCIO ACTIVO**

No se mostrarán:

- teléfono;

- email;

- fecha de nacimiento;

- datos de pago.

## **RF-021. Validez del carnet**

El carnet estará vinculado a una temporada.

Un socio que no haya renovado no deberá aparecer como socio activo de la
nueva temporada.

# **11. Blog**

## **RF-022. Publicación**

El administrador podrá publicar noticias o comunicaciones para sus
socios.

Cada publicación tendrá inicialmente:

- título;

- texto;

- imagen opcional;

- fecha de publicación.

## **RF-023. Consulta del blog**

Los socios podrán consultar las publicaciones desde la aplicación.

El contenido será privado.

Solo será accesible tras iniciar sesión y pertenecer al club
correspondiente.

No existirá inicialmente un blog público.

# **12. Ventajas para socios**

## **RF-024. Gestión de ventajas**

El administrador podrá publicar ventajas destinadas a los socios.

En el MVP serán publicaciones sencillas.

Ejemplo:

**10 % de descuento en Restaurante X**

Presentando tu carnet de socio obtendrás un 10 % de descuento.

## **RF-025. Consulta de ventajas**

El socio dispondrá del apartado:

**Mis ventajas**

donde verá las ventajas vigentes publicadas por su club.

Las ventajas podrán estar relacionadas con patrocinadores.

# **13. Patrocinadores**

## **RF-026. Gestión de patrocinadores**

El administrador podrá:

- dar de alta patrocinadores;

- modificar patrocinadores;

- activar/desactivar patrocinadores;

- asociarlos a temporadas.

## **RF-027. Datos del patrocinador**

Inicialmente se almacenará:

- nombre;

- logotipo;

- URL de su web.

Podrán añadirse posteriormente otros datos comerciales o fiscales.

## **RF-028. Patrocinadores por temporada**

Los patrocinadores estarán vinculados a temporadas.

Un patrocinador de la temporada 2026/2027 no deberá aparecer
automáticamente en 2027/2028.

Deberá renovarse su relación con el club.

## **RF-029. Visualización**

Los socios podrán consultar los patrocinadores activos del club.

Cada patrocinador mostrará:

- logotipo;

- nombre;

- enlace a su web.

El enlace abrirá la página del patrocinador.

# **14. Aplicación del socio**

La navegación principal del socio tendrá inicialmente los siguientes
apartados:

### **Inicio / Blog**

Noticias y comunicaciones del club.

### **Mi carnet**

Carnet digital y QR.

### **Mis ventajas**

Ventajas disponibles para socios.

### **Mi suscripción**

Temporada, cuota, método de pago, renovaciones, histórico y recibos.

### **Mis datos**

Información personal del socio.

# **15. Selector de clubes**

## **RF-030. Varios clubes**

Cuando el usuario pertenezca a más de un club, podrá seleccionar el club
al que desea acceder.

Cada club se mostrará mediante:

- logotipo;

- nombre;

- identidad visual propia.

El cambio de club no requerirá volver a iniciar sesión.

# **16. Administración del club**

La aplicación web del administrador tendrá inicialmente las siguientes
áreas:

### **Dashboard**

Resumen básico del club.

### **Socios**

Alta, baja, modificación, renovación y consulta.

### **Temporadas**

Creación, activación y gestión.

### **Pagos**

Consulta de cuotas, estados y recibos.

### **Patrocinadores**

Alta, modificación y asociación a temporada.

### **Ventajas**

Alta, modificación y publicación.

### **Blog**

Creación y gestión de publicaciones.

### **Configuración**

Datos e identidad visual del club.

# **17. Administrador principal**

La administración global permitirá:

### **Clubes**

- crear club;

- modificar club;

- activar/desactivar club;

- acceder al club.

### **Suplantación funcional**

El administrador principal podrá acceder a la administración de
cualquier club con los mismos permisos que su administrador.

El sistema deberá mantener identificado que la acción fue realizada por
el administrador principal.

# **18. Reglas de negocio principales**

### **RN-001**

No existe registro público de socios.

### **RN-002**

Todo socio debe ser dado de alta inicialmente por un administrador.

### **RN-003**

El email identifica al usuario de forma global.

### **RN-004**

Un usuario puede pertenecer a varios clubes.

### **RN-005**

Un usuario solo puede tener una cuenta global aunque pertenezca a varios
clubes.

### **RN-006**

El número de socio pertenece a la relación usuario-club y no al usuario
global.

### **RN-007**

La condición de socio debe mantenerse por temporada.

### **RN-008**

Las cuotas están vinculadas a una temporada.

### **RN-009**

Cada temporada dispone de una cuota general.

### **RN-010**

La cuota puede personalizarse para cada socio.

### **RN-011**

La renovación de socios podrá realizarse masivamente.

### **RN-012**

El socio deberá recibir un aviso antes de cualquier renovación
automática.

### **RN-013**

El socio podrá cancelar la renovación antes del cargo.

### **RN-014**

El carnet válido corresponde a una temporada concreta.

### **RN-015**

Las ventajas pertenecen a un club.

### **RN-016**

Los patrocinadores están vinculados a temporadas.

### **RN-017**

Todo el contenido de la aplicación de socios será privado salvo la
página mínima de validación del QR.

# **19. Modelo conceptual simplificado**

Las principales entidades serán:

USUARIO

├── nombre

├── apellidos

├── email

├── teléfono

├── fecha_nacimiento

└── foto

CLUB

├── nombre

├── código

├── logo

└── configuración visual

USUARIO_CLUB

├── usuario

├── club

├── número_socio

└── rol

TEMPORADA

├── club

├── nombre

├── cuota_general

└── estado

SOCIO_TEMPORADA

├── socio

├── temporada

├── cuota

└── estado

PAGO

├── socio_temporada

├── importe

├── fecha

├── estado

├── proveedor_pago

└── referencia

PATROCINADOR

├── club

├── nombre

├── logo

└── web

PATROCINADOR_TEMPORADA

├── patrocinador

└── temporada

PUBLICACION

├── club

├── título

├── contenido

└── fecha

VENTAJA

├── club

├── patrocinador opcional

├── título

├── contenido

└── estado

# **20. Identidad visual por club**

Cada club podrá disponer de:

- nombre;

- logotipo;

- imagen;

- colores principales.

La aplicación utilizará esta configuración para personalizar:

- pantalla de selección de club;

- cabecera;

- carnet;

- navegación;

- comunicaciones;

- recibos.

La aplicación será técnicamente única aunque visualmente cada club pueda
percibirse como un espacio independiente.

# **21. Alcance del MVP**

El MVP incluirá:

- plataforma multi-club;

- administrador principal;

- administrador de club;

- usuarios socios;

- autenticación por email/contraseña;

- autenticación Google;

- invitación de socios;

- perfil de socio;

- temporadas;

- renovación masiva;

- cuotas generales y personalizadas;

- integración con sistema de pago;

- renovación automática;

- aviso previo de renovación;

- histórico de pagos;

- recibos;

- carnet digital;

- QR de validación;

- blog privado;

- patrocinadores;

- ventajas;

- selector de clubes;

- personalización visual básica por club.

# **22. Fuera del MVP**

Quedan inicialmente fuera:

- registro público de usuarios;

- acceso de patrocinadores;

- gestión comercial de patrocinadores;

- contratos de patrocinio;

- facturación;

- contabilidad;

- gestión de gastos;

- equipos deportivos;

- jugadores;

- entrenadores;

- licencias federativas;

- estadísticas deportivas;

- tienda online;

- mensajería entre socios;

- notificaciones push avanzadas;

- códigos promocionales avanzados;

- métricas para patrocinadores;

- múltiples administradores por club;

- web pública del club.

Estas funcionalidades podrán incorporarse en fases posteriores.
