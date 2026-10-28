# SF3 3rd Strike (sfiii3 / sfiii3nr1) · RAM map

CPS3 (SH-2, big-endian). Direcciones del bus emulado tal como las lee `memory.read*` en fcadefbneo.
Estado: **V** = validado en vivo por CIPHER · **T** = tomado del training mode, sin validar todavía.

| Campo | Dirección / offset | Tipo | Estado | Notas |
|---|---|---|---|---|
| Struct jugador P1 | `0x02068C6C` | — | V | stride `0x498` |
| Struct jugador P2 | `0x02069104` | — | V | |
| Posición X | `+0x64` | s16 | V | px de escenario (corner ≈ 912, inicio 430/600) |
| Posición Y | `+0x68` | s16 | T | 0 en el piso |
| Orientación | `+0x0A` | u8 | V | 1 = mira a la derecha, 0 = izquierda |
| Vida | `+0x9F` | u8 | V | máx 160 (`0xA0`); 255 tras KO / fuera de round |
| Char ID | `+0x3C0` | u16 | V parcial | 1 = Alex, 2 = Ryu, 7 = Ibuki, 11 = Ken confirmados; resto del orden en `game.lua` (T) |
| Estado de match | `0x020154A6` | u32 | V | `0` fuera, `0x0001xxxx` intro, `0x0002xxxx` pelea, `0x0009xxxx` char select |
| Timer | `0x02011377` | u8 | V | 99 → 0 |
| Super meter P1 / P2 | `0x020695BE` / `0x020695EB` | u8 | T | |
| Combo recibido P1 / P2 | `0x020696C5` / `0x0206961D` | u8 | T | |
| Screen X / Y | `0x02026CB0` / `0x02026CB4` | s16 | T | |
| Hitbox ptrs | `+0x2A0..+0x2D4` | ptr | T | ver `cps3-hitboxes.lua` |

| Animación | `+0x202` | u16 | **V** | clave de la frame data de effie (`af68` = Ken cr.HP); 100% de coincidencia |
| Hash de frame | `+0x21A` (u16) `+0x214` (u8) `+0x205` (u8) | — | **V** | sync contra `sync` de la frame data: 332/332 frames |
| Cajas (vuln/ataque/throw…) | ptr `+0x2A0/+0x2A8/+0x2C8/+0x2B8/+0x2C0/+0x2D4` | `l,w,b,h` s16 | **V** | cajas de ataque en vivo caen 100% en `hit_frames` |
| Velocidad X/Y | `+0x7C`/`+0x80` (+mantisa) | s16 | V | relativa a la orientación (`flip`) |
| Hitstop | `+0x45` | u8 | T | `>=128` => `256-v` |
| Postura | `+0x20E` | u8 | T | 0 parado, 6/8 caminar, 0x20 agachado, 0x14–0x1E aire, 0x26 en el piso |
| Atacando / bloqueando | `+0x428` / `+0x3D3` | u8 | T | bloqueo = 1..4 |
| Agarrado | `+0x3CF` | u8 | T | |
| Proyectiles | lista 3 en `0x02068A96`, base `0x02028990 + idx<<11`, siguiente `+0x1C` | — | **V** | tipo `+0x91`, emisor `+0x2` |
| Selección de personaje | col `0x0201566B`/`0x0201566D`, fila `0x020154CF`/`0x020154D1`, SA `0x020154D3`/`0x020154D5` | u8 | **V** (escritura) | forzado Ryu/Ken OK |
| Match | `0x020154A7` (u8) == 2 y menú `0x0201546B` == 4 | — | V | |

| Conexión recibida | marker `+0x32E` (u16), contador `+0x33E` (u16) | — | **V** | `0xFFF1` sin hit nuevo = parry real; otro marker = bloqueo; contador sube = golpe |
| Ventana de parry | `blocking_id` `+0x3D3` 5..8 | u8 | **V** | ventana ABIERTA (también al caminar adelante), no parry exitoso |
| Meter (stock / gauge) | `0x020695BF`/`0x020695EB` stock, `0x020695B5`/`0x020695E1` gauge | u8 | **V** | Ken SA3: stock 1 tras gauge 80; SA3 sale con qcf qcf+K de 1 frame por dirección |

Post-parry de suelo: el defensor queda con freeze 0 y el atacante con freeze 19, más la recuperación que le quede (~35 frames de ventaja contra un normal).

Fuentes cruzadas: effie3rd/3rd_training_lua `memory_addresses.lua` (GPL-3.0), PainPekooo/fight-with-daigo `memory.lua`, pearmannick-prog/sfiii3-cps3-decomp (`plw_layout.csv`).

## Emulador (fcadefbneo.exe sha256 95cf8987…28d7, REA/Ghidra)

- `joypad.set` = `0x413c60`: llena overrides en `0x03193e00[idx]` (1 = press, 2 = release) y levanta el flag `0x03174c22`.
- `RunFrame` = `0x449960`: netplay → `FUN_004496e0` (InputMake) → `FUN_0042a6b0` (sync GGPO) → callbacks Lua `FUN_00412ce0` → `FUN_00418570` (aplica overrides de joypad.set) → emula.
  ⇒ online, `joypad.set` es **solo local** (desync). La inyección online va por SendInput (backend `keys`).
- Mapeo default de teclas P1 (calibrado): flechas, A/S/D = LP/MP/HP, Z/X/C = LK/MK/HK, 5 = coin, 1 = start.
- CLI: `fcadefbneo.exe <rom|state.fs> <script.lua>` carga el script (sin comillas en las rutas). `quark:direct,<rom>,<lport>,<ip>,<rport>,<player>,…` = netplay directo; arranca desde `savestates\<rom>_fbneo.fs`.
