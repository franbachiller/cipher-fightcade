# CIPHER Fightcade

Bot que juega **Street Fighter III: 3rd Strike** en Fightcade (emulador fcadefbneo), con reacción frame a frame guiada por la frame data real del juego. Lee el estado desde la RAM del emulador, predice los ataques del rival y responde con parry, anti-air, castigos y combos verificados, para los 19 personajes.

Es un proyecto de **ingeniería inversa y IA de juego de pelea**: la parte difícil no es apretar botones, sino leer el estado exacto, predecir en qué frame llega cada golpe y decidir la mejor respuesta dentro de la ventana que permite el juego.

## Cómo funciona

```
Emulador fcadefbneo  ──RAM──>  state.lua (sensor)  ──>  predict.lua  ──>  brain (fundamentals)
   (SF3 3rd Strike)              posición, vida,          cajas de ataque     decide: parry / anti-air /
        ▲                        frames, medidor...       futuras del rival   castigo / combo / footsies
        │                                                                          │
        └──────────  core/output (keys vía SendInput, o joypad.set offline)  ◄─────┘
```

- **Sensor** (`games/sfiii3/state.lua`): lee de la RAM posición, vida, estado de animación, frames de recuperación y medidor de super. El mapa de direcciones está en [`data/sfiii3/ram-map.md`](data/sfiii3/ram-map.md).
- **Predicción** (`games/sfiii3/predict.lua`): cruza las cajas de ataque futuras del rival (según la frame data) con mis cajas vulnerables, extrapola proyectiles y responde "golpe en N frames" y a qué altura (bajo / medio / overhead).
- **Cerebro** (`games/sfiii3/brains/fundamentals.lua`): prioriza throw tech → combo en curso → anti-air → castigo post-parry → parry/bloqueo → castigo de recuperación → hit-confirm → presión en wakeup → footsies.
- **Combos verificados por fuerza bruta** (`tools/combo_lab_pool.ps1`): prueba cada normal → especial/super/link en cada frame posible contra un dummy y lo valida en RAM (contador de combo y daño). Salen 2108 combos con la ventana exacta de cada uno, que el cerebro usa en castigos garantizados. Un pool de hasta 12 emuladores reparte el trabajo.
- **Salida** (`core/output.lua`): online entra por named pipe → `tools/cipher_keys.py` → SendInput (1 frame de latencia, antes de GGPO); offline usa `joypad.set`, frame-exacto.

## Controles

| Tecla | Acción |
| --- | --- |
| Insert | bot ON / OFF |
| Home | lado controlado (P1 ↔ P2) |
| End | overlay ON / OFF |
| PageUp | overlay de debug (RAM en vivo) |

El overlay muestra el estado en vivo: `CIPHER ON P1 [fundamentals]` y qué está haciendo (parry, punish, anti-air…).

## Uso rápido

1. Doble clic en `CIPHER.bat` (consola, dejar abierta).
2. Entrar a una partida de SF3 3rd Strike en Fightcade: la consola detecta el emulador y carga `cipher.lua` sola.
3. `Insert` activa el bot; juega apenas empieza la pelea.

El manual completo (uso online/offline, calibración, evaluación, laboratorio de combos) está en [`docs/MANUAL.md`](docs/MANUAL.md).

## Evaluación

Las corridas son deterministas (misma semilla), así que cada cambio se mide contra números exactos: `tools/eval.ps1 -Turbo` enfrenta al bot contra un sparring aleatorio, e `-Arcade` corre el modo arcade completo e imprime rivales vencidos y diagnóstico de parries y castigos.

## Stack

Lua (lógica del bot, ~1000 archivos entre código y datos de personajes), Python (bridge de teclado, importadores y análisis) y PowerShell (laboratorio de combos, evaluación y calibración).

## Atribución

Este repositorio contiene **solo el código propio** y los datos que el bot consume. No incluye:

- Los repos de referencia de terceros (`third_party/`): [effie3rd/3rd_training_lua](https://github.com/effie3rd), fight-with-daigo, donsinp-design y la decompilación de CPS3, usados como fuente de reversing.
- La frame data (`data/sfiii3/fd/`) y los movelists (`data/sfiii3/moves/`) importados de **effie3rd/3rd_training_lua** y reformateados con `tools/import_framedata.py` / `import_movelist.py`.
- El proyecto Ghidra de UMK3 y el wiki scrapeado, por tratarse de material de terceros.

El juego y sus datos pertenecen a Capcom. Esto es un proyecto personal de investigación; usar un bot en partidas contra personas va contra las reglas de Fightcade.

## Licencia

Código propio. Los componentes de terceros conservan su licencia original.
