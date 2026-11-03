# frontend_parchis

Proyecto de frontend de parchis

## Tests

```bash
flutter test
# Partida online real contra un servidor local (PARCHIS_DEV_AUTH_BYPASS=true PARCHIS_ALLOW_TEST_MODE=true):
PARCHIS_E2E_URL=ws://localhost:8080/ws flutter test test/e2e
```

CI (`.github/workflows/ci.yml`) corre en cada pull request y en cada push a `Jorge` o `main`:

| Job | Qué verifica |
|---|---|
| `test` | `flutter analyze` + tests |
| `e2e` | La app juega una partida online contra `parchis_server` (misma rama si existe, si no `main`) |
| `android` | El proyecto Android compila (`flutter build apk --debug`, sin firmar ni publicar) |

Para que un fallo bloquee el merge, activa en GitHub *Settings → Branches* la regla de la rama con *Require status checks to pass* y marca estos jobs.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
