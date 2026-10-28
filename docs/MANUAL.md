# CIPHER-Fightcade

Bots para juegos de pelea en Fightcade (fcadefbneo). Primer juego: SF3 3rd Strike (`sfiii3nr1`).

## CIPHER Console (recomendado)

1. Doble clic en `CIPHER.bat` (dejala abierta).
2. Entrá a una partida de SF3 3rd Strike en Fightcade (online u offline). La consola detecta el emulador y carga
   `cipher.lua` sola; el bot se activa y juega apenas empieza la pelea, con el personaje que elijas.
3. El lado (P1/P2) se detecta solo al empezar cada round. **Insert** pausa / reactiva, **Home** fuerza el lado.
4. La ventana del emulador tiene que estar enfocada mientras juega el bot (los inputs van por teclado).

## Uso online manual (sin consola)

1. Una sola vez, calibrar el teclado del emulador (si cambiás el mapeo, repetir):
   ```
   powershell -File tools\calibrate.ps1
   ```
2. Antes de jugar: `powershell -File tools\start_online.ps1` (dejar abierta).
3. En la ventana del emulador: **Game > Lua Scripting > New Lua Script Window**, elegir `cipher.lua` y **Run**.
4. Overlay arriba: `CIPHER OFF P1 [fundamentals] keys`. Con **Home** elegís tu lado y con **Insert** activás o desactivás el bot. Debajo se muestra qué está haciendo (parry, punish, anti-air...).

| Tecla | Acción |
|---|---|
| Insert | bot ON / OFF |
| Home | lado controlado P1 ↔ P2 (en online: tu lado) |
| End | mostrar / ocultar overlay |
| PageUp | overlay de debug (RAM en vivo) |

También se pueden bindear a botones de joystick: Input > Map Lua Hotkeys (1 = toggle, 2 = lado).

## Cerebro `fundamentals`

Reacción frame-exacta guiada por la frame data (`data\sfiii3\fd\`, importada de effie3rd/3rd_training_lua).
Prioridades: throw tech → combo en curso → anti-air → castigo post-parry → parry/bloqueo → castigo de recuperación → hit-confirm → presión en wakeup → footsies.

- **Predicción** (`games\sfiii3\predict.lua`): cajas de ataque futuras del rival (frame data) contra mis cajas vulnerables, más proyectiles extrapolados. Da "golpe en N frames" y altura (bajo / medio / overhead).
- **Parry**: 1 frame neutral y después el toque (el juego exige una pulsación nueva), palanca neutral durante la ventana.
- **Castigos**: ventaja real = freeze del rival + recuperación restante. Si sobra tiempo camina hasta el rango del combo más fuerte.
- **Personajes**: `games\sfiii3\chars\<char>.lua` a mano (Ken, Ryu) completado con `chars\auto.lua`, que genera pokes, anti-airs y castigos de los 19 personajes desde la frame data.
- Ajustes en `config.lua`: `parry_rate`, `parry_lead`, `block_lead`, `antiair_rate`, `poke_rate`, `walk_back_rate`.

## Combos verificados (laboratorio)

`tools\combo_lab_pool.ps1 -Chars ken,ryu,...` prueba por fuerza bruta cada normal → especial / super / normal en cada frame
posible y verifica en RAM (contador de combo + daño). Resultado: `data\sfiii3\combos\<char>_d60.lua` con la ventana exacta `t`
(frames desde el starter) de cada combo. 19 personajes, 2108 combos.

- Niveles: `-Level 1` normal → especial/super/link; `-Mode chain` normal → normal en la zona de cancel temprana
  (chains de 3S); `-Level 2 -NoLinks` cadenas verificadas (links/chains) → especial/super.
  Archivos: `<char>_d60.lua`, `<char>_d60_chain.lua`, `<char>_d60_L2.lua`. 19 personajes, 1418 combos limpios.
- Criterio estricto: el contador de combo no puede volver a 0 entre golpes, y el objetivo es la suma real de golpes
  de cada normal (algunos pegan 2-3 veces; se miden al arrancar cada worker).
- Pool de 12 emuladores con claims atómicos por starter, reparto por carga, speedmode máximo, corte temprano,
  búsqueda gruesa (cada 2 frames + vecinos de cada éxito), poda de variantes. Re-ensayo dirigido: `-KeepParts -OnlyFile`.
- Savestates: solo slot numerado (`savestate.create(9)`); el anónimo crashea fcadefbneo. Cada carga se valida
  (estado guardado en el primer frame); si no "agarra" se reintenta cada 8 frames (`CIPHER_LAB_FASTRELOAD=1`: cada frame, Oro).
- El brain los usa en castigos (combo completo garantizado) y en hit-confirm real (`games\sfiii3\combos.lua`).
- Inputs de especiales/supers: `data\sfiii3\moves\<char>.lua` (importados de effie con `tools\import_movelist.py`).

## Backends de salida

- `keys` (online): `cipher.lua` → named pipe → `tools\cipher_keys.py` → SendInput. Entra antes de GGPO y tiene 1 frame de latencia. La ventana del emulador tiene que estar enfocada. Mientras el bot está ON, no toques el teclado: las teclas del bot y las tuyas se pisan.
- `lua` (offline): `joypad.set`, frame-exacto. Online solo afecta tu emulación (desync), ver `data\sfiii3\ram-map.md`.
- `auto` (default): usa `keys` si el helper está corriendo y `lua` si no.

## Evaluación

Las corridas son deterministas (misma semilla), así que cada cambio se compara con números exactos.

- `tools\eval.ps1 -Turbo`: bot (P2 Ken) contra un sparring aleatorio (P1 Ryu). Cuando P1 pierde, Ken sigue el arcade contra la CPU.
- `tools\eval.ps1 -Turbo -Arcade`: arcade completo con el bot en P1. Imprime rivales vencidos, diagnóstico de parries y de castigos post-parry.
- `tools\validate_state.lua`, `tools\validate_super.lua`: validación del sensor y del medidor/super en vivo.
- `tools\run_test.ps1`, `tools\net_test_keys.ps1`: pruebas de F0 (offline y netplay local).

## Estructura

```
cipher.lua            entrypoint (controladores: bot + sparring opcional)
config.lua            teclas, lado, brain, backend, tuning
core\                 hotkeys, input (cola + motions), output (keys/lua), overlay, log, metrics
games\sfiii3\         game.lua, state.lua (sensor), framedata.lua, predict.lua, brains\, chars\
data\sfiii3\          ram-map.md, fd\ (frame data por personaje)
tools\                harness, evaluación, validaciones, calibración, cipher_keys.py (bridge), import_framedata.py
(third_party\ con los repos de referencia no se incluye en este repositorio)
```
