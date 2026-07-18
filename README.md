# Baby Monitor

Aplicación Flutter que convierte cualquier celular Android en una cámara IP (monitor de bebé / vigilancia) transmitida en vivo por la red local (WiFi), con audio, detección de movimiento y visor multiplataforma — incluyendo un cliente web sin instalar nada.

No depende de internet ni de servidores externos: todo el streaming ocurre dentro de tu propia red WiFi, dispositivo a dispositivo.

## Índice

- [Características](#características)
- [Casos de uso](#casos-de-uso)
- [Arquitectura](#arquitectura)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Uso](#uso)
- [Seguridad](#seguridad)
- [Stack técnico](#stack-técnico)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Limitaciones conocidas](#limitaciones-conocidas)
- [Contacto](#contacto)

## Características

- **Modo Servidor**: usa la cámara (frontal/trasera) y el micrófono del celular como emisor. Sirve video MJPEG y audio PCM16 por HTTP dentro de la LAN.
- **Modo Cliente**: otra instancia de la app se conecta al servidor pegando la URL del stream — funciona en Android, iOS, Windows, macOS, Linux (lo que soporte Flutter).
- **Cliente web (sin instalar nada)**: el servidor expone una página HTML propia (`http://<ip>:<puerto>/`) que cualquier navegador puede abrir para ver el video y escuchar el audio, sin necesidad de la app cliente.
- **Streaming en segundo plano (Android)**: al minimizar la app servidor, un foreground service (`camera|microphone`) mantiene la transmisión activa con notificación persistente.
- **Detección de movimiento**: comparación de frames en el servidor; dispara un evento (`Server-Sent Events`) que hace sonar una alerta y resalta el video en rojo tanto en la app cliente como en el navegador.
- **Audio del stream**: captura PCM16 en el servidor, buffer de jitter y reproducción en el cliente (Flutter) o Web Audio API (navegador).
- **Pantalla siempre activa (cliente web)**: usa la Screen Wake Lock API; si el navegador la bloquea (por ejemplo, HTTP plano sobre IP de LAN, que no es "contexto seguro"), cae a un fallback con video silencioso en loop para evitar que el sistema apague/bloquee la pantalla.
- **Sonido activado por defecto (cliente web)**: intenta activar el audio automáticamente al cargar la página; si las políticas de autoplay del navegador lo bloquean, se activa con el primer toque/clic del usuario en cualquier parte de la página.
- **Autenticación por token**: cada sesión de servidor genera un token aleatorio de 24 bytes; toda URL (stream, audio, eventos, página web) lo exige como query param. Regenerable manualmente desde la app (invalida enlaces anteriores).

## Casos de uso

- **Monitor de bebé**: cámara en la cuna, visor en el celular/tablet de los padres en otra habitación.
- **Monitor de mascotas**: vigila a tu mascota mientras no estás en casa (misma red WiFi).
- **Cuidado de adultos mayores**: cámara en la habitación de una persona que requiere supervisión.
- **Cámara de seguridad DIY**: cualquier celular viejo se convierte en cámara IP para garaje, entrada, taller o bodega.
- **Monitor de habitación remota**: revisar una sala, oficina o cuarto de servidores desde otro dispositivo en la misma red.
- **Videovigilancia sin suscripciones**: alternativa gratuita a cámaras IP comerciales cuando solo necesitas cobertura dentro del hogar/oficina.

## Arquitectura

Clean Architecture por feature (Domain → Data → Presentation), con BLoC/Cubit para estado e inyección de dependencias vía `get_it`:

```
lib/
├── core/
│   ├── background/     # Control del foreground service Android
│   ├── di/              # Contenedor de dependencias (get_it)
│   ├── security/        # Generación/almacenamiento del token de acceso
│   └── theme/
├── features/
│   ├── camera_server/   # Modo emisor (cámara + servidor HTTP)
│   │   ├── domain/      # Entidades y contratos de repositorio
│   │   ├── data/        # Captura de cámara/audio, servidor MJPEG (HttpServer), detección de movimiento
│   │   └── presentation/# Cubit + UI (preview, controles, info de conexión)
│   └── stream_client/   # Modo receptor (visor del stream)
│       ├── domain/
│       ├── data/        # Consumo de /stream, /audio, /events; buffer de audio
│       └── presentation/# Cubit + UI (viewer MJPEG, overlay de alerta)
└── main.dart
```

## Requisitos

- Flutter SDK `^3.13.0-282.1.beta` (canal indicado en `pubspec.yaml`).
- Dispositivo Android para el **modo Servidor** (usa foreground service, notificaciones y permisos nativos de cámara/micrófono/batería — no soportado en modo servidor sobre iOS/desktop/web).
- Cualquier plataforma soportada por Flutter (o solo un navegador) para el **modo Cliente**.
- Ambos dispositivos en la **misma red WiFi/LAN**.

## Instalación

```bash
git clone <url-del-repo>
cd flutter_cam_baby_monitor
flutter pub get
flutter run
```

Para generar el APK de Android:

```bash
flutter build apk --release
```

## Uso

### 1. Configurar el servidor (celular que hace de cámara)

1. Abre la app y entra a la pestaña **Servidor**.
2. Otorga los permisos de cámara y micrófono cuando se soliciten.
3. Pulsa **Iniciar Stream**. La app muestra:
   - La IP local y el puerto (por defecto `8080`).
   - Una URL de stream (`http://<ip>:<puerto>/stream?token=...`) para consumir desde la app cliente.
   - Una URL de navegador (`http://<ip>:<puerto>/?token=...`) para abrir desde cualquier navegador.
4. Puedes cambiar de cámara (frontal/trasera) con el botón correspondiente sin detener el stream.
5. Al minimizar la app, el streaming continúa en segundo plano (Android) gracias al foreground service.
6. El ícono de llave regenera el token de acceso e invalida cualquier enlace compartido previamente.

### 2. Conectarse como cliente

**Opción A — App Flutter:**
1. En otro dispositivo, abre la app y entra a la pestaña **Cliente**.
2. Pega la URL de stream mostrada por el servidor.
3. Pulsa **Conectar**. Puedes pasar a pantalla completa con el ícono correspondiente.

**Opción B — Navegador (sin instalar nada):**
1. Abre la URL de navegador (`http://<ip>:<puerto>/?token=...`) en Chrome/Edge/Firefox de cualquier dispositivo en la misma red.
2. El video, el audio de alerta y la detección de movimiento funcionan directamente en la página.

## Seguridad

- Cada arranque del servidor usa un token aleatorio criptográficamente seguro (24 bytes, `Random.secure()`).
- Todas las rutas del servidor (`/stream`, `/audio`, `/events`, `/`) rechazan peticiones sin el token correcto (`401 Unauthorized`).
- El servidor solo escucha en la red local; no expone nada a internet salvo que el propio router/NAT lo redirija explícitamente (no recomendado).
- El token puede regenerarse en cualquier momento desde la app, invalidando enlaces filtrados o antiguos.

## Stack técnico

- **Flutter / Dart** — UI y lógica multiplataforma.
- **flutter_bloc** — gestión de estado (Cubit).
- **get_it** — inyección de dependencias.
- **camera** — captura de video nativo.
- **record** — captura de audio PCM16.
- **flutter_pcm_sound** — reproducción de audio PCM16 en el cliente.
- **dart:io HttpServer** — servidor HTTP embebido (video MJPEG, audio, eventos SSE, página web del cliente).
- **network_info_plus** — resolución de IP local (WiFi).
- **permission_handler** — permisos de cámara, micrófono, notificaciones, batería.
- **flutter_secure_storage** — almacenamiento seguro del token de acceso.
- **equatable** — comparación de estados inmutables.

## Estructura del proyecto

Ver [Arquitectura](#arquitectura) arriba para el árbol de `lib/`. Tests unitarios y de widgets en `test/`, siguiendo la misma estructura por feature.

## Limitaciones conocidas

- El modo Servidor con foreground service y notificaciones persistentes es específico de Android; en otras plataformas el streaming solo funciona en primer plano.
- La Screen Wake Lock API del navegador requiere contexto seguro (HTTPS o `localhost`); sobre `http://<ip-lan>` cae automáticamente al fallback de video en loop.
- Las políticas de autoplay de audio del navegador pueden requerir un primer clic/toque del usuario antes de que suene el audio, según el navegador.
- Sin soporte multi-servidor: la app está pensada para una relación 1 emisor ↔ N espectadores en la misma red.

## Contacto

**Developed by:** Paul Realpe
**Email:** paulmrg461@gmail.com
**Teléfono:** 3148580454
**Web:** [https://devpaul.co/](https://devpaul.co/)
