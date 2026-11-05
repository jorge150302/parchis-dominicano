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

`.github/workflows/ci.yml` corre en cada pull request y en cada push a `main`, la rama principal. Todos los jobs corren siempre: app y servidor comparten el protocolo.

| Job | Qué verifica |
|---|---|
| `core` | Tests del motor compartido: uno por cada regla de `docs/reglas.md` |
| `server` | `dart analyze` y tests unitarios del servidor |
| `app` | `flutter analyze` y tests de la app, incluidos los de pantallas: desbordes en 5 tamaños y 2 tamaños de letra, y capturas de referencia (*goldens*) |
| `firestore` | Reglas de seguridad y transacciones contra el emulador de Firestore |
| `docker` | La imagen del servidor compila, responde `/health` y no contiene credenciales |
| `stress-e2e` | Servidor real: prueba de estrés rápida (salas concurrentes, clientes hostiles, fugas) y la app jugando una partida online contra él |
| `android` | El proyecto Android compila (`flutter build apk --debug`, sin firmar ni publicar) |

`.github/workflows/android-emulators.yml` instala la app real en emuladores Android y juega una partida offline. En cada pull request usa Android 7 y 16 (API 24 y 36), y cada noche Android 7, 10, 14 y 16 (API 24, 29, 34 y 36).

Para que un fallo bloquee el merge: *Settings → Branches* → regla para la rama principal → *Require status checks to pass* → marca estos jobs, más `android-24` y `android-36`.

### Capturas de referencia (goldens)

`app/test/screens_golden_test.dart` compara 4 pantallas (menú, selección de jugadores, sala online y tablero), en celular y en tablet, con las imágenes guardadas en `app/test/goldens/`. Solo se comparan en Linux, como en la CI, porque en Windows las fuentes se dibujan distinto.

- **Si una captura no coincide:** el job `app` falla y deja el artifact `golden-failures`, con la imagen vieja, la nueva y la diferencia.
- **Si el cambio era a propósito:** ponle al PR la etiqueta **`actualizar-capturas`**. El workflow *Actualizar capturas* regenera las imágenes en Linux, las agrega al PR, y en *Files changed* se ven la imagen vieja y la nueva lado a lado.
- **Si el repo no tiene el secret `GOLDENS_TOKEN`:** cierra y vuelve a abrir el PR para que la CI corra otra vez.
