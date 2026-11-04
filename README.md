# Parchís Dominicano

Monorepo del juego:

| Carpeta | Qué es |
|---|---|
| [`app/`](app/) | App Flutter (Android). Antes repo `parchis-dominicano` |
| [`server/`](server/) | Servidor de partidas online (Dart Frog, WebSocket). Antes repo `parchis_server` |
| [`packages/parchis_core/`](packages/parchis_core/) | Reglas, tableros y motor de turnos que usan la app y el servidor. Las reglas están en [`docs/reglas.md`](docs/reglas.md) |

Cada carpeta conserva su historial de git, su `pubspec.yaml` y su README con los detalles de ejecución.

## Desarrollo local

```bash
# Servidor sin credenciales de Firebase, con salas de prueba
cd server
PARCHIS_DEV_AUTH_BYPASS=true PARCHIS_ALLOW_TEST_MODE=true dart_frog dev --hostname 0.0.0.0

# App (otra terminal) apuntando al servidor local
cd app
flutter run --dart-define=PARCHIS_WS_URL=ws://<ip-del-pc>:8080/ws   # emulador: ws://10.0.2.2:8080/ws
```

En Android Studio abre la carpeta `app/`.

## CI

`.github/workflows/ci.yml` corre en cada pull request y en cada push a `main` o `Jorge`. Todos los jobs corren siempre: app y servidor comparten el protocolo.

| Job | Qué verifica |
|---|---|
| `core` | Tests del motor compartido: uno por cada regla de `docs/reglas.md` |
| `server` | `dart analyze` y tests unitarios del servidor |
| `app` | `flutter analyze` y tests de la app |
| `firestore` | Reglas de seguridad y transacciones contra el emulador de Firestore |
| `docker` | La imagen del servidor compila, responde `/health` y no contiene credenciales |
| `stress-e2e` | Servidor real: prueba de estrés rápida (salas concurrentes, clientes hostiles, fugas) y la app jugando una partida online contra él |
| `android` | El proyecto Android compila (`flutter build apk --debug`, sin firmar ni publicar) |

Para que un fallo bloquee el merge: *Settings → Branches* → regla para la rama principal → *Require status checks to pass* → marca estos jobs.
