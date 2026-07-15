# Bomberos Cotacachi — Sistema de Alertas

App móvil (Flutter) del Cuerpo de Bomberos de Cotacachi para gestionar
emergencias en tiempo real: alertas, respuesta del personal, rastreo del
trayecto de cada bombero, eventos institucionales y gestión de usuarios.

Construida 100% con servicios gratuitos: **Firebase Spark** (Auth + Firestore
+ FCM), **Cloudinary** (archivos adjuntos) y **OpenStreetMap** (mapas).

## Funcionalidades

| Rol | Puede |
|---|---|
| **Admin** | Todo lo del bombero + finalizar operativos, ver el trayecto de cada bombero, gestionar personal y roles, marcar el personal de guardia semanal, agendar eventos |
| **Bombero** | Crear alertas (categoría, mapa, adjunto, destinatarios), recibir alertas push, confirmar "Voy en camino" con ETA, compartir su trayecto GPS en vivo, ver historial y eventos |

## Personal de guardia (notificaciones semanales)

En **Menú → Personal de Guardia** el admin marca quiénes están de turno esa
semana. Las alertas enviadas a "Todo el personal" solo notifican por push al
personal de guardia (campo `de_guardia` en `usuarios`; sin el campo se asume
de guardia). Los demás siguen viendo las alertas al abrir la app. Los envíos
a un "Grupo selectivo" y los eventos institucionales no se filtran.

> **Nota:** al actualizar a esta versión hay que volver a desplegar
> `firestore.rules` (ahora cualquier usuario autenticado puede crear
> emergencias): `firebase deploy --only firestore:rules`.

## Rastreo de trayecto (diseño para plan gratuito)

Cuando un bombero confirma asistencia, la app registra su recorrido en
`emergencias/{id}/trayectos/{uid}`:

- El GPS emite un punto cada ~20 m de movimiento, pero **se escribe a
  Firestore máximo 1 vez cada 30 s** agrupando los puntos pendientes en un
  solo `arrayUnion` → ~120 escrituras/hora por bombero (el plan gratuito da
  20.000/día).
- En Android corre como **servicio en primer plano** (notificación fija), así
  el rastreo sigue aunque el bombero minimice la app para usar Google Maps.
- Se apaga solo cuando el admin finaliza la emergencia, o manualmente con
  "Dejar de compartir mi ubicación".
- La central ve el recorrido como una línea sobre el mapa, en vivo.

## Notificaciones push

Se envían con **FCM HTTP v1** usando *topics* (`todos` y `u_<uid>`), sin
backend. Requiere colocar una credencial de cuenta de servicio con permiso
mínimo — instrucciones completas en [`assets/credenciales/LEEME.md`](assets/credenciales/LEEME.md).
Sin la credencial la app funciona igual (las alertas llegan en tiempo real
con la app abierta), solo no hay push con la app cerrada.

## Estructura

```
lib/
├── config/        # Tema, iconos, mensajes (snackbars)
├── modelos/       # EmergenciaModelo, CategoriaModelo
├── pantallas/     # Login, dashboard, crear/detalle alerta, eventos, personal
├── servicios/     # Auth, emergencias, rastreo GPS, notificaciones, Cloudinary
└── widgets/       # Menú lateral, tarjetas, listas
```

Colecciones en Firestore: `usuarios`, `emergencias` (+ subcolección
`trayectos`), `categorias`, `eventos`.

## Compilar

```bash
flutter pub get
flutter run                # desarrollo
flutter build apk --release --obfuscate --split-debug-info=build/simbolos
```

> **Pendiente antes de publicar en Play Store:** cambiar el `applicationId`
> (`com.example.bomberos_app`) por uno propio y registrar esa nueva app
> Android en la consola de Firebase (descargar el nuevo `google-services.json`).
