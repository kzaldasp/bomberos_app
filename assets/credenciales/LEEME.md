# Credencial de FCM (notificaciones push)

Para que la app pueda ENVIAR notificaciones push se necesita una cuenta de
servicio de Google con permiso **únicamente** de mensajería. Sin este archivo
la app funciona igual, solo que no envía push (las alertas siguen llegando en
tiempo real con la app abierta).

## Pasos (una sola vez)

1. Entra a https://console.cloud.google.com/iam-admin/serviceaccounts
   y selecciona el proyecto **bomberos-alerta-app**.
2. Crea una cuenta de servicio nueva, ej. `envio-fcm`.
3. En "Rol" asigna SOLO: **Administrador de la API de Firebase Cloud Messaging**
   (`roles/firebasemessaging.admin`). NO le des Editor ni Propietario.
   Así, si alguien extrajera la credencial del APK, solo podría enviar
   notificaciones: no puede tocar Firestore, usuarios ni archivos.
4. En la pestaña "Claves" → "Agregar clave" → JSON. Se descarga un archivo.
5. Renombra ese archivo a `fcm_service_account.json` y colócalo en ESTA carpeta:

   assets/credenciales/fcm_service_account.json

6. Compila. Listo.

## Medidas de seguridad aplicadas

- El archivo está en `.gitignore`: **nunca** se sube al repositorio.
- La cuenta de servicio tiene el mínimo permiso posible (solo enviar FCM).
- Compila los releases con ofuscación para dificultar extraer la credencial:

  flutter build apk --release --obfuscate --split-debug-info=build/simbolos

- Si sospechas que la credencial se filtró: en la consola de Google Cloud,
  elimina la clave de la cuenta de servicio y genera una nueva. Las apps
  antiguas dejan de poder enviar al instante.
