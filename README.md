# Mr. Apache Pizzería

Aplicación Flutter para explorar la carta y gestionar pedidos de los locales Mr. Apache de Huancayo. La app utiliza Firebase Authentication y Cloud Firestore. Los pedidos quedan en estado **Pendiente** hasta que un administrador los confirme.

## 1. Crear y preparar el proyecto

Este repositorio ya contiene un proyecto Flutter. Para crear uno nuevo desde cero:

```powershell
flutter create --platforms=android mr_apache_hyo
cd mr_apache_hyo
```

Las dependencias se declaran en `pubspec.yaml`. Para instalarlas o actualizar el lockfile:

```powershell
flutter pub get
```

Paquetes usados: `firebase_core`, `firebase_auth`, `cloud_firestore`, `provider`, `intl`, `url_launcher`, `google_fonts`, `cached_network_image` y `flutter_launcher_icons`.

El identificador Android actual es `com.company.MrApacheHyo` (`android/app/build.gradle.kts`) y debe coincidir exactamente con el cliente Android de Firebase.

## 2. Conectar Firebase

1. En [Firebase Console](https://console.firebase.google.com/), crea un proyecto.
2. En **Agregar app**, elige Android y usa `com.company.MrApacheHyo` como nombre del paquete.
3. Descarga `google-services.json` y guárdalo en `android/app/google-services.json`. El archivo recibido se conserva también en `android/google-services.json`.
4. En **Authentication → Sign-in method**, habilita **Correo electrónico/Contraseña** y **Anónimo**. El acceso anónimo permite navegar por inicio y carta sin registrarse; confirmar un pedido requiere una cuenta registrada.
5. En **Firestore Database**, crea una base de datos. Publica las reglas de [`firestore.rules`](./firestore.rules) desde la pestaña **Reglas**.
6. Desde la raíz ejecuta:

   ```powershell
   flutter pub get
   flutter run
   ```

El plugin de Google Services, minSdk 23, permisos de Internet/llamada y dependencias Firebase Android están configurados en `android/`. El archivo actual de `android/app/google-services.json` corresponde al proyecto Firebase que ya está configurado en esta copia; reemplázalo si usarás otro proyecto.

### Icono de la app

El logo proporcionado está en `assets/images/logo.png`, declarado como asset en `pubspec.yaml`. El mismo recurso se usa como icono Android y foreground adaptativo sobre fondo negro. Para regenerar los iconos después de reemplazar el arte:

```powershell
flutter pub get
dart run flutter_launcher_icons
flutter clean
```

### Alternativa con FlutterFire CLI

Con Flutter instalado, inicia sesión en Firebase y ejecuta:

```powershell
dart pub global activate flutterfire_cli
flutterfire configure
```

Selecciona el proyecto Firebase y Android. FlutterFire genera `lib/firebase_options.dart`; después importa `firebase_options.dart` en `lib/main.dart` y cambia la inicialización por:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

Si FlutterFire no descarga `google-services.json`, descárgalo desde la consola y colócalo en `android/app/` igualmente.

## 3. Reglas y acceso administrador

Las reglas de Firestore completas están en [`firestore.rules`](./firestore.rules). En resumen:

- Las cuentas solo pueden leer y editar su perfil sin cambiar el campo `role`.
- Los clientes solo pueden leer y editar sus direcciones y reseñas, y sus reservas.
- Los pedidos son legibles por su propietario y por administradores. El cliente solo puede crearlos como `Pendiente` y cancelar los pendientes; cambiar otros estados queda reservado al administrador.
- El catálogo (productos, categorías, sucursales y promociones) es legible para usuarios autenticados y solo el administrador puede escribir.
- Los pedidos y los datos del catálogo requieren que Firebase Authentication esté habilitado.

Para crear el primer administrador: registra una cuenta desde la app. En Firebase Console abre **Firestore → users → {uid de la cuenta}**, cambia `role` de `cliente` a `admin` y guarda. El UID se encuentra en **Authentication → Users**. No habilites escrituras públicas ni asignes el rol desde la app cliente.

## 4. Datos iniciales y esquema

Inicia sesión con una cuenta que tenga `role: "admin"`, abre **Perfil → Panel de administrador → Cargar datos iniciales**. La operación crea o actualiza documentos con IDs estables, así que puede repetirse sin duplicar locales y carta. El catálogo se puede editar después desde Productos, Sucursales y Promos. No reemplaza datos no relacionados.

Esquema recomendado (los tiempos se guardan como `Timestamp` de Firestore):

| Colección | Campos principales |
|---|---|
| `users/{uid}` | `nombres: string`, `apellidos: string`, `nombreCompleto: string`, `telefono: string`, `correo: string`, `role: string`, `fechaRegistro: timestamp` |
| `users/{uid}/addresses/{addressId}` | `name: string`, `address: string`, `primary: boolean`, `createdAt: timestamp` |
| `branches/{branchId}` | `name: string`, `address: string`, `phone: string`, `openingTime: string`, `closingTime: string`, `acceptsDelivery: boolean` |
| `categories/{categoryId}` | `name: string` |
| `products/{productId}` | `name: string`, `category: string`, `description: string`, `prices: map<string, number>`, `image: string`, `available: boolean` |
| `promotions/{promotionId}` | `name: string`, `description: string`, `price: number`, `image: string` |
| `orders/{orderId}` | `number: string`, `userId: string`, `customerName: string`, `customerFirstName: string`, `customerLastName: string`, `customerPhone: string`, `items: array<map>`, `subtotal: number`, `deliveryFee: number`, `total: number`, `branchId: string`, `branchName: string`, `deliveryType: string`, `address: string`, `payment: string`, `notes: string`, `status: string`, `createdAt: timestamp`, `business: map` |
| `reviews/{reviewId}` | `userId: string`, `customerName: string`, `stars: number`, `comment: string`, `createdAt: timestamp`, `updatedAt: timestamp` |
| `reservations/{reservationId}` | `userId: string`, `date: timestamp`, `time: string`, `people: number`, `branchId: string`, `branchName: string`, `status: string` |

La app incluye carta editable con combos, pizzas, pastas, carnes, bebidas y extras; sucursales iniciales, horario de cena y almuerzo, teléfonos y datos tributarios de Inversiones Cesarvero S.A.C.

## 5. Uso y pruebas manuales

1. Abre la app: el acceso y el registro deben cargar luego de configurar Firebase.
2. Registra una cuenta con nombres y apellidos (letras/tildes/ñ/espacios, al menos 2 caracteres cada campo), celular peruano de 9 dígitos, correo y contraseña de al menos 6 caracteres con confirmación.
3. Navega por Inicio y Carta; verifica el selector de sucursal, búsqueda, categoría, tamaño de pizza y notas.
4. Agrega productos, modifica cantidades, elimínalos y vacía el carrito.
5. Mientras el local esté abierto, confirma un pedido con delivery o recojo. Para delivery ingresa dirección. Revisa subtotal, envío (S/ 3.00; gratis desde S/ 50.00), pago y notas.
6. Revisa **Mis pedidos**, cancela uno pendiente y observa los estados con la actualización en tiempo real.
7. En Perfil prueba editar nombre/teléfono, agregar/editar/marcar/eliminar direcciones, guardar/editar/eliminar reseñas y reservar/editar/cancelar/eliminar mesa.
8. Asigna `role: "admin"` a una cuenta de prueba en Firestore. Verifica el panel, carga inicial, CRUD de productos y sucursales, promociones y cambio/filtrado de estado de pedidos.
9. Prueba **Explorar sin cuenta** antes de registrarte; revisa Nosotros/Contacto (mapa, llamada, WhatsApp, web) y cierra sesión.

Las pruebas unitarias de `test/cart_provider_test.dart` cubren el cálculo/edición del carrito, la validación y normalización de nombres y la lectura de perfiles antiguos. Ejecútalas junto al análisis con:

```powershell
flutter clean
flutter pub get
dart run flutter_launcher_icons
flutter test
flutter analyze
flutter run -d emulator-5554
```

Las consultas de pedidos del cliente y reservas filtran únicamente por `userId` y ordenan los resultados en memoria; no requieren índices compuestos. Las consultas administrativas ordenan solo por `createdAt`, con índice simple automático.

## 6. Errores frecuentes

- **Falta `google-services.json`**: confirma que exista como `android/app/google-services.json` y que corresponda al `applicationId`.
- **Error de paquete Android**: el identificador registrado en Firebase debe coincidir exactamente con `applicationId` en `android/app/build.gradle.kts`.
- **SDK mínimo**: Firebase requiere Android minSdk 23 o superior; este proyecto fija un mínimo efectivo de 23.
- **Gradle no encuentra el plugin Google Services**: no elimines el bloque del plugin en `android/settings.gradle.kts`; ejecuta `flutter clean` y luego `flutter pub get`.
- **Permission denied en Firestore**: publica `firestore.rules`, inicia sesión y verifica el documento `users/{uid}`. Las operaciones administrativas requieren `role: "admin"`.
- **La app muestra pantalla de configuración Firebase**: el SDK cliente no tiene opciones válidas para Android; instala el `google-services.json` correcto o configura FlutterFire.
- **El botón de pedido está bloqueado por horario**: se aceptan pedidos en línea según el horario guardado en cada sucursal. Cambia el horario desde el panel admin si el local lo requiere.
- **Windows informa que hacen falta symlinks**: habilita **Developer Mode** en la configuración de Windows y vuelve a ejecutar `flutter pub get`.
