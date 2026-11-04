# parchis_core

Las reglas, los tableros y el motor de turnos del Parchís Dominicano. Los usan la app (partidas offline) y el servidor (partidas online), así que una regla se escribe y se prueba **una sola vez**.

La explicación de cada regla y de cada decisión pendiente está en [`docs/reglas.md`](../../docs/reglas.md).

## Contenido

| Archivo | Qué contiene |
|---|---|
| `lib/src/rules.dart` | `RulesConfig`: una opción por cada decisión del documento de reglas. `RulesConfig.official` es la configuración con la que se juega. |
| `lib/src/engine.dart` | `ParchisEngine`: tirada (`roll`), avance (`step`), resolución de la casilla y las capturas (`land`) y cambio de turno (`nextTurn`). |
| `lib/src/board.dart` | Tableros como datos: `BoardDefinition`, con su JSON y su validación. |
| `lib/src/boards.dart` | Catálogo incluido: `easy`, `medium` (el de online), `hard` y `quick`. |

El motor no tira el dado ni anima nada. Eso lo hacen la app y el servidor, cada uno con sus propios modelos de jugador, que implementan `RulesPlayer` y `RulesToken`.

## Cambiar una regla

1. Cambia el valor por defecto en `RulesConfig` (`lib/src/rules.dart`).
2. Corre `dart test`. Hay un test por cada opción en `test/engine_test.dart`.
3. Actualiza la tabla de respuestas en `docs/reglas.md`.

## Agregar un tablero

1. Agrega un `BoardDefinition` en `lib/src/boards.dart` y súmalo a `bundledBoards`. El `id` no puede cambiar nunca: las salas y las partidas guardadas lo referencian.
2. La validación rechaza los tableros que no se pueden jugar: acciones fuera del camino, en la última casilla o saltos fuera del tablero.
3. Mide cuánto duran sus partidas:

```bash
dart run tool/match_length.dart 500 4   # 500 partidas por fila, 4 s por tirada
```

## Tests

```bash
dart pub get
dart test
```
