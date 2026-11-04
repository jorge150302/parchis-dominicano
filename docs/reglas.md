# Reglas del Parchís Dominicano

Borrador para decidir. Hoy las reglas están escritas dos veces: una en la app, usada en partidas offline, y otra en el servidor, usada en partidas online. Las dos versiones no son iguales, así que una misma jugada puede dar un resultado distinto según el modo.

Cuando estén decididas, este documento será la referencia, y el motor compartido `parchis_core` (Fase 3) implementará solo estas reglas, con un test por regla.

**Cómo responder:** en cada decisión, elige una opción (por ejemplo "D1: A"). Si no estás seguro, la recomendada es la que menos cambia el juego actual.

> **Estado actual:** las reglas ya están en el motor compartido `parchis_core`, y la app y el servidor juegan con las mismas. Cada decisión es una opción de `RulesConfig` (`packages/parchis_core/lib/src/rules.dart`):
> - **D1 a D5:** está activa la opción recomendada (⭐).
> - **P1 y P2:** se mantiene lo de hoy.
>
> Cambiar una decisión es cambiar una línea, y hay un test para cada opción.

---

## 1. Lo que ya es igual en los dos lados

Estas reglas solo hay que confirmarlas. Si alguna no te gusta, dilo.

| # | Regla actual |
|---|---|
| R1 | Cada jugador tiene **2 fichas**. Empiezan en casa (casilla 0). |
| R2 | Se sale de casa con **cualquier número**: no hace falta sacar 5 ni 6. |
| R3 | Las fichas avanzan por un camino **compartido** por todos. Tiene 100 casillas en el tablero medio, el que se usa online, y 49 en el fácil. La ficha termina al llegar a la última casilla. |
| R4 | **Tiro exacto:** si el dado te pasa de la meta, esa ficha no se puede mover. |
| R5 | Si ninguna ficha se puede mover, pierdes el tiro. |
| R6 | **Sacar 6** da un turno extra, aunque no puedas mover. |
| R7 | **Captura:** si caes donde hay fichas rivales, vuelven a casa y ganas **1 turno extra por cada ficha capturada**. |
| R8 | Casillas especiales: **a casa** (tu ficha vuelve a la salida), **repite tiro** (turno extra), **pierde turno** (pierdes tu próximo turno) y **salto** (la ficha va a otra casilla, hacia adelante o hacia atrás). |
| R9 | Si sacas **6 y caes en "pierde turno"**, se anulan los dos: no pierdes turno y no tienes turno extra. |
| R10 | La partida sigue **hasta que solo queda un jugador** con fichas en juego. El orden de llegada define las posiciones. |

---

## 2. Diferencias que hay que decidir

### D1. Tres seises seguidos

| | Qué pasa hoy |
|---|---|
| App (offline) | **Una** ficha, la primera que esté en el tablero, vuelve a casa. Pasa el turno. |
| Servidor (online) | **Todas** las fichas que no llegaron a la meta vuelven a casa. Pasa el turno. Además se borran los "pierde turno" que tenías pendientes, lo que en la práctica es un premio escondido. |

- **A.** Una ficha a casa, como la app. Es menos castigo. ⭐ Recomendada.
- **B.** Todas las fichas a casa, como el servidor, pero sin borrar los "pierde turno" pendientes.
- **C.** Sin ficha a casa: solo pierdes el turno.

### D2. Meter una ficha en la meta

| | Qué pasa hoy |
|---|---|
| App (offline) | Ganas **1 turno extra**, salvo que fuera tu última ficha. |
| Servidor (online) | No ganas nada. |

- **A.** Turno extra, como la app. Acorta un poco las partidas. ⭐ Recomendada.
- **B.** Sin premio, como el servidor.

Hay un caso dentro de este: si una casilla de **salto** te lleva directo a la meta, hoy no hay premio en ningún lado. Con la opción A, ¿también ganas el turno extra en ese caso? Recomiendo **sí**, para que la regla sea igual sin importar cómo llegues.

### D3. Puentes (bloqueos)

Dos fichas del mismo jugador en una casilla forman un puente, y nadie puede pasar ni caer ahí.

| | Qué pasa hoy |
|---|---|
| App (offline) | El puente bloquea a **todos**, también a su dueño, en todo el camino. |
| Servidor (online) | Igual hasta la casilla 68. **Después de la 68** el puente solo bloquea a su dueño y los rivales pasan. Es un resto del parchís clásico de 68 casillas que no tiene sentido en este tablero. |

- **A.** El puente bloquea a todos en todo el camino, como la app. ⭐ Recomendada.
- **B.** El puente solo bloquea a los rivales: el dueño puede pasar por su propio puente.
- **C.** No hay puentes: dos fichas juntas no bloquean nada.

### D4. Una casilla de salto que te manda a un puente

| | Qué pasa hoy |
|---|---|
| App (offline) | Si el destino del salto es un puente, **no saltas** y te quedas donde caíste. |
| Servidor (online) | **Saltas igual** y quedas encima del puente. |

- **A.** No saltas, como la app. Respeta la regla del puente. ⭐ Recomendada.
- **B.** Saltas igual, como el servidor. Las casillas de salto mandan sobre los puentes.

Si en D3 eliges C (sin puentes), esta decisión ya no aplica.

### D5. ¿Los tres seises se cuentan dentro de un mismo turno?

| | Qué pasa hoy |
|---|---|
| App (offline) | El contador se pone en cero solo cuando sacas algo distinto de 6. En casos raros, como un 6 que cae en "pierde turno", el contador pasa a tu turno siguiente. |
| Servidor (online) | El contador se pone en cero cada vez que cambia el turno. |

- **A.** Solo cuentan los seises seguidos de un mismo turno, como el servidor. ⭐ Recomendada.
- **B.** Cuentan aunque haya pasado el turno, como la app.

---

## 3. Preguntas que definen el juego (y cuánto dura)

No son diferencias entre los dos lados. Hoy una partida de 4 jugadores pasa de 20 minutos aun con bots instantáneos (Fase 4.3), y estas respuestas deciden eso.

### P1. ¿Cuándo termina la partida?
- **A.** Cuando solo queda un jugador, como hoy. Es la más larga.
- **B.** Cuando gana el primero. Los demás se ordenan por lo avanzado que estén. Una partida de 4 dura más o menos lo mismo que una de 2. ⭐ Recomendada para online.
- **C.** Cuando llegan 2 jugadores en partidas de 3 o 4, y cuando llega 1 en partidas de 2.

### P2. ¿Cuántas fichas por jugador?
- **A.** 2, como hoy. ⭐ Recomendada.
- **B.** 4, como el parchís tradicional. Las partidas duran casi el doble.

### P3. ¿Qué tablero se usa online?
Offline hay tres tableros: fácil (49 casillas, sin castigos), medio (100) y difícil (100, con más castigos). Online siempre se juega en el **medio**.
- **A.** Siempre el medio, como hoy.
- **B.** Quien crea la sala elige el tablero. Así se puede ofrecer un tablero corto para partidas rápidas. Encaja con la Fase 4 y con los tableros de pago. ⭐ Recomendada.

### P4. ¿Cuál es la duración objetivo de una partida de 4 jugadores?
La respuesta es un número de minutos, por ejemplo "menos de 10 minutos". Con ese número ajusto P1, el tablero y la velocidad de las animaciones, y lo dejo como una prueba automática en la CI.

**Duración medida.** Son 500 partidas simuladas por fila con `packages/parchis_core/tool/match_length.dart`, calculando unos 4 segundos por tirada. Online hoy se juega siempre en el tablero **medio**.

| Tablero | Jugadores | Hasta que queda uno (hoy) | Hasta que gana el primero |
|---|---|---|---|
| Medio (100) | 2 | ~15 min | ~15 min |
| Medio (100) | 4 | **~50 min** | ~29 min |
| Fácil (49) | 4 | ~12 min | ~8 min |
| Difícil (100) | 4 | ~2 h 15 min | ~66 min |
| **Rápido (60, nuevo)** | 2 | ~5 min | ~5 min |
| **Rápido (60, nuevo)** | 4 | ~15 min | **~10 min** |

El tablero **rápido** (`quick`) ya está en el catálogo para la Fase 4.3. No se usa por defecto: para usarlo online hace falta decidir P3.

### P5. Confirmar R2 y R4
- R2: ¿salir de casa con cualquier número, o solo con 5 o 6?
- R4: ¿tiro exacto para entrar a la meta, o "rebote" (lo que sobra se retrocede)?

---

## 4. Errores encontrados al comparar (corregidos)

- El tablero fácil se generaba con **49** casillas, pero la app lo reconocía como tablero fácil solo si tenía **50**. Ahora el servidor manda el `boardId` del tablero y la app dibuja ese.
- La cantidad de fichas estaba fijada en 2 en varios lugares de la app y del servidor. Ahora sale de un solo lugar: `RulesConfig.tokensPerPlayer`.
- Se eliminó el resto del parchís de 68 casillas que aparecía en D3.
- Si una tirada no se podía mover, el servidor guardaba los turnos extra pendientes para más adelante en vez de usarlos en ese momento. Ahora se usan en el momento, igual que en la app.

---

## Respuestas

| Decisión | Elección |
|---|---|
| D1 Tres seises | |
| D2 Ficha en la meta (y caso del salto) | |
| D3 Puentes | |
| D4 Salto hacia un puente | |
| D5 Contador de seises | |
| P1 Fin de partida | **A**: hasta que queda un solo jugador |
| P2 Fichas por jugador | 2, como hoy (sin cambios) |
| P3 Tablero online | **A**: siempre el medio |
| P4 Duración objetivo | **30 a 60 minutos** para 4 jugadores online. Hoy dura ~50 minutos; lo vigila `packages/parchis_core/test/match_length_test.dart` |
| P5 Salida y meta | Salir de casa con **cualquier número** (R2). Falta confirmar el tiro exacto para entrar a la meta (R4) |
