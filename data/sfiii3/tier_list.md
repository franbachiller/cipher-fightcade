# CIPHER — tier list del bot (SF3 3rd Strike)

Rendimiento **medido** de CIPHER con cada personaje, no el tier competitivo humano. Puntaje = historial online
(pesa según cuántas peleas hay) + combos verificados en emulador para su SA. Se regenera con
`python -I tools\tier_list.py` después de jugar o de verificar combos.

| Tier | Personaje | SA | Online (G-P) | Daño hecho/recibido | Combos con super | Mejor combo con super | Combos sin barra |
|---|---|---|---|---|---|---|---|
| S | Ken | SA III | 29-4 | 1.47 | 18 | cl.HP xx shoryuken:MP xx SA (57) | 4 |
| S | Ryu | SA II | 5-2 | 1.22 | 16 | cl.MP xx shoryuken:HP xx SA (91) | 6 |
| S | Akuma | SA I | 7-4 | 1.20 | 21 | cl.HP xx tatsumaki:LK, tatsumaki:HK xx SA (59) | 8 |
| S | Chun-Li | SA II | 9-5 | 1.13 | 8 | cl.MP xx SA (64) | 2 |
| A | Sean | SA III | 0-1 | 0.37 | 13 | cl.HK xx SA (73) | 9 |
| A | Makoto | SA I | 0-1 | 0.80 | 8 | 2MK xx SA (76) | 6 |
| A | Yang | SA I | — | — | 5 | 2LK > 2LK xx SA (69) | 4 |
| A | Ibuki | SA III | 0-1 | 1.01 | 10 | cl.MK xx SA (55) | 5 |
| B | Remy | SA II | 1-1 | 0.91 | 6 | cl.HP xx SA (60) | 3 |
| B | Yun | SA II | — | — | 6 | 2LK > 2LK xx SA (50) | 7 |
| B | Hugo | SA III | 6-4 | 0.99 | 1 | 2LP > 2LP xx SA (60) | 2 |
| B | Twelve | SA I | — | — | 6 | cl.MP xx SA (54) | 2 |
| B | Necro | SA III | 1-1 | 0.99 | 5 | 4LK > MP xx SA (49) | 3 |
| B | Alex | SA II | 0-1 | 0.56 | 6 | cl.MK xx SA (60) | 4 |
| B | Elena | SA II | 0-1 | 0.70 | 3 | 2MP xx SA (65) | 3 |
| C | Dudley | SA I | 0-2 | 0.63 | 7 | cl.HP xx SA (64) | 1 |
| C | Q | SA I | 0-3 | 0.62 | 2 | cl.MK xx dashing_head_attack:LP xx SA (64) | 4 |
| C | Oro | SA II | 1-4 | 0.84 | 3 | cl.MP xx SA (31) | 14 |
| C | Urien | SA III | 1-2 | 0.98 | 0 | — | 3 |

## Por qué ese SA

- **Akuma — SA I**: wiki: SA1 'by far the most practical choice'
- **Alex — SA II**: wiki: SA2 'the super of choice for Alex'
- **Chun-Li — SA II**: wiki: SA2 'Very, very recommended'; SA3 'Not recommended'
- **Dudley — SA I**: wiki: SA1 'one of Dudley's two best'; SA2 'the least popular option'
- **Elena — SA II**: wiki: SA2 'where it really shines' (SA1 empata en EX); bot: SA2 3 combos (max 65)
- **Hugo — SA III**: wiki: SA1 y SA3 'Recommended'; bot: Gigas (agarre) no tiene combos, SA3 sí (2LP > 2LP xx SA, 60)
- **Ibuki — SA III**: wiki: SA3 'easy to combo into from a plethora of options'; bot: SA3 10 combos, SA1 1
- **Ken — SA III**: wiki: SA3 'Recomended / the universal choice'; SA1 y SA2 'Not recommended'
- **Makoto — SA I**: wiki: SA1 'Highly recommended'
- **Necro — SA III**: wiki (página Necro): 'Super Art 3 is the main'
- **Oro — SA II**: wiki: SA1 'Not recommended'; SA2 loops / SA3 presión; bot: SA2 3 combos, SA3 1
- **Q — SA I**: wiki: SA1 'usually the best choice'
- **Remy — SA II**: wiki: SA2 'Midscreen damage and punishes'; SA3 'Pay one bar of meter to lose'
- **Ryu — SA II**: wiki: SA2 'devastating'; SA3 (Denjin) exige cargar con el botón: el bot no lo hace; bot: SA2 16 combos, max 91
- **Sean — SA III**: wiki: SA3 '1f nuke'; SA2 'poor hit-confirm range'; bot: SA3 13 combos, max 73
- **Twelve — SA I**: wiki: SA1 'your go-to pick'
- **Urien — SA III**: wiki: SA1 y SA2 'Not Recommended', SA3 'Character defining'
- **Yang — SA I**: wiki: SA3 es instalación (el bot no la explota); SA1 '74 de daño, invencible'; bot: SA1 5 combos, max 69
- **Yun — SA II**: wiki: 'Sourai Rengeki would likely be Yun's first choice if Genei Jin wasn't so dominant'; Genei-Jin necesita combos en vivo que el bot no verificó
