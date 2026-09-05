# Navegación

Dos subsistemas orientan al jugador por el mapa: `core/nav/pathfinder.rb` calcula la ruta hasta un objetivo y
`core/audio/audio3d.rb` construye el paisaje sonoro. El Locator elige el objetivo; las guías consumen la ruta.

## Búsqueda de rutas

| Llamada | Devuelve |
|---|---|
| `find_path(tx, ty)` | Direcciones RPG (`8` `2` `4` `6`) hasta una casilla **adyacente** al destino; `[]` si ya está al lado, `nil` si no hay ruta |
| `path_to_text(path)` | La ruta hablada ("3 arriba, 2 izquierda"), o el texto de "no hay ruta" / "al lado" |
| `legs(path)` | La ruta en tramos `[dirección, casillas]`; `leg_text(leg)` habla uno |
| `reachable_set` | `{ pkey => true }` de casillas alcanzables, cacheado por casilla del jugador |
| `surf_launch(tx, ty)` | Ruta a la orilla alcanzable más cercana al destino, o `nil` |
| `reach` | Tope de distancia manhattan configurado (`route_reach`) |

El origen es **siempre** `$game_player`: no hay parámetro de partida. Se llega con `target_reached?`
(manhattan ≤ 1), porque el objetivo típico —NPC, cartel, objeto— ocupa una casilla en la que no se entra.

```ruby
# core/nav/pathfinder.rb
def self.find_path(tx, ty)
  with_budget do
    with_bridges do
      px = ($game_player.x rescue 0); py = ($game_player.y rescue 0)
      far = (px - tx).abs + (py - ty).abs > FLOOD_MIN
      next nil if far && blocked_target?(tx, ty)
      find_path_to(tx, ty, false) || find_path_to(tx, ty, true)
    end
  end
end
```

`with_bridges` fuerza `$PokemonGlobal.bridge = 2` durante la búsqueda, para cruzar un puente al que el jugador
aún no ha subido. `blocked_target?` descarta el destino con el flood cacheado, solo más allá de `FLOOD_MIN` (24)
casillas, con el flood completo y sin `edge_relax`. Dos pasadas: sin saltos de desnivel, y con ellos si falla.

### Algoritmos

`path_algorithm` elige la frontera; la expansión de vecinos y el desempate por menos giros son comunes.

| Valor | Frontera | Prioridad | Nota |
|---|---|---|---|
| `:astar` (defecto) | montículo binario | `2g + 2h` | ruta óptima; también donde cae un valor desconocido |
| `:weighted` | montículo | `2g + 3h` | pesos doblados para expresar 1,5x en enteros puros |
| `:greedy` | montículo | `2h` | directo al objetivo, propenso a rodeos |
| `:dijkstra` | montículo | `2g` | óptimo sin heurística, explora más |
| `:bfs` / `:dfs` | cola / pila | — | sin montículo; DFS solo para experimentar |
| `:jps` | puntos de salto | `g + h` | un pasillo recto cuesta una expansión |
| `:hpa` | grafo de clusters | `g + h` | jerárquico, para mapas grandes |

`straight_routes` suma +1 al coste de cada giro. JPS cae a A* (`@jps_fallback`) con hielo, deslizadores,
recursión de más de 80 niveles o al agotar su presupuesto de pasos (`[astar_max * 8, 20000]`). HPA* divide el
mapa en clusters de `HPA_CLUSTER` (10) casillas y rutea de portal en portal hasta un sumidero sintético
(`HPA_SINK`), refinando cada salto con un A* local **vivo**: un grafo obsoleto solo produce `:fallback`, nunca
una ruta errónea. Ambos, solo en la primera pasada.

### Vecinos especiales

`step_target(cx, cy, dir, allow_ledge, edge_relax)` resuelve a qué casilla entra la búsqueda. El agua no es un
caso aparte: la pasabilidad del juego ya depende de `$PokemonGlobal.surfing`.

| Terreno | Vecino resultante |
|---|---|
| Desnivel (tag 1) | Nunca es nodo pisable: se comprueba **antes** que la pasabilidad, porque los motores modernos lo declaran pasable desde el lado alto. Cruzarlo es siempre el salto de dos casillas (`ledge_jump`), con `allow_ledge`, un aterrizaje real y el bit de paso del lado opuesto abierto (`LEDGE_OPP_BIT`; permisivo si el tileset no se puede leer) |
| Hielo (tag 12) | Donde **acaba** el deslizamiento (`ice_slide`), no la casilla contigua; tope de 200 pasos |
| Deslizador | Evento sin gráfico que fuerza una ruta de movimiento. `slide_index` los indexa por mapa (`pkey => { dirección => destino }`) y la búsqueda salta al destino |
| Borde del mapa | Con `edge_relax`, una casilla de borde pasable vale como vecino aunque falle el paso direccional |

### Cachés y presupuesto

`$game_player.passable?` es caro y una búsqueda lo llama miles de veces. Con `route_cache` se memoiza por
`[map_id, surfing, diving]`, con clave `pkey(cx, cy) * 16 + d`; no sigue a los eventos que se mueven, por eso se
puede apagar. `invalidate_cache(force = false)` tira pasabilidad, alcanzables, grafo de HPA*, ruta de surf e
índice de deslizadores; va throttleada a 2 s, y `Caches` la registra con `force = true` (sin throttle) para el
cambio de mapa y la carga de partida.

`reachable_tiles` es un BFS con la expansión de la búsqueda (saltos permitidos, deslizadores montados,
`edge_relax` en false), acotado por `reach`, 10 000 nodos y el mismo plazo; si se corta, `@rs_full` queda en false
y `blocked_target?` deja de rechazar nada. `reachable_set` lo cachea por `[x, y, map_id]` y lo comparten
`hide_unreachable`, la lista de superficies y `surf_launch`.

Por defecto la búsqueda corta por **nodos** (`astar_max`, 2500); con `route_auto` corta por **tiempo**
(`route_budget_ms`, 8 ms) y `over_budget?` mira el reloj cada `BUDGET_CHECK` (256) nodos. El plazo es uno por
**llamada a `find_path`**, no por búsqueda: las hasta tres que puede lanzar una ruta lo comparten y anidar
`with_budget` conserva el de fuera. Lo respetan todas salvo el A* local de `hpa_low`. Agotado el plazo, aún se
devuelve una **ruta parcial** si el mejor nodo quedó a 2 casillas o menos del destino.

### Las dos guías

Las dos consumen la MISMA ruta cacheada -- `refresh_guide_path` la calcula una vez y `advance_guide_path` la
va gastando conforme el jugador anda -- y se diferencian solo en lo que emiten:

| Guía | Tecla | Emite | Cadencia |
|---|---|---|---|
| Bastón (`toggle_guide`) | Mayús+I | Chime panoramizado hacia el siguiente paso | Reloj (`guide_freq`), se espacia con la distancia |
| Paso a paso (`toggle_steps`) | Ctrl+I | El tramo actual hablado, "6 arriba" | Al cambiar de casilla, y solo si el tramo es nuevo |

`Pathfinder.legs` parte la ruta en tramos `[dirección, casillas]`: `path_to_text` los une todos (tecla I) y
`announce_leg` lee solo el primero. Habla cuando cambia la dirección, o cuando el mismo tramo se ALARGA tras
un desvío; mientras solo encoge, calla. Comparten el pestillo de "sin ruta" y el final del trayecto
(`stop_guides`), así que llegar no se anuncia dos veces aunque las dos estén encendidas.

## Categorías del localizador

Shift + flecha cambia de categoría; la flecha sola recorre la lista, ordenada por distancia. El nombre
hablado sale de la clave `tcat_*` correspondiente.

| Símbolo | Qué lista |
|---|---|
| `:all` | Todo lo alcanzable con las teclas: sprites de personaje y eventos examinables |
| `:people` / `:objects` | El reparto de `event_category`: quien se mueve o habla, y lo demás |
| `:exits` | Transferencias de mapa, con las puertas anchas colapsadas en una sola |
| `:signs` | Carteles y eventos que solo muestran texto |
| `:extras` | Peligros, trampas, controles, empujadores y teletransportes |
| `:surfaces` | Objetivos sintéticos: la casilla más cercana de cada superficie a la que se puede llegar |
| `:puzzles` | Celdas declaradas por un perfil a través de la API de puzles |
| `:lens` | Baldosas de la Lente de la Verdad (`#EOT`), solo si el mapa tiene alguna |
| `:marks` | Los marcadores del jugador (`Ctrl`+`G`), solo en los mapas donde puso alguno |

Las siete primeras son `Config.categories` y persisten en `settings.ini`. `:puzzles`, `:lens` y `:marks` no:
se insertan solo cuando el mapa las tiene, para no ofrecer una categoría vacía.

## Audio 3D

`PA3D_steam.dll` (Steam Audio HRTF + miniaudio) es el único motor de audio del mod: por él pasan también los
pasos y los choques. Necesita `phonon.dll` de la misma arquitectura en `accessibility/lib`.

| Entrada | Firma `Win32API` | Uso |
|---|---|---|
| `PA3D_Init` | `[] → i` | arranque; debe devolver 1 |
| `PA3D_Channel` | `["p", "i"] → i` | carga un wav (ruta terminada en `"\0"`) y devuelve su canal; 2º arg = bucle |
| `PA3D_Listener` | `["i", "i"] → v` | coloca el oyente sobre el jugador |
| `PA3D_Set` | `["i", "i", "i", "i", "i"] → v` | coloca y reproduce un canal |
| `PA3D_Master` | `["i"] → v` | volumen maestro |

Cada entrada se resuelve bajo `rescue`, así que una dll ausente la deja en `nil`: `available?` exige esas cinco
y `PA3D_Rate`, `PA3D_Latency`, `PA3D_Occl`, `PA3D_Air` y `PA3D_Pitch` (tono por canal, en porcentaje de la grabación; el menú de tonos) son opcionales. `boot` corre una sola vez, exige
`INIT.call == 1`, lee tasa y latencia del dispositivo y carga los canales; los assets ya vienen en la tasa
nativa (44100 en `accessibility/sounds/`, 48000 en `sounds/48000/`, y `wav(name)` escoge).

**`PA3D_Set` no tiene eje Z.** Sus cinco enteros son `(canal, x, y, volumen, on)`: el cuarto es el volumen
0-100, no una altura, y el quinto es 1 para reproducir/posicionar y 0 para silenciar. Las coordenadas de
casilla se escalan por `TILE_UNITS` (100), para que la distancia de la HRTF coincida con el mapa:

```ruby
# core/audio/audio3d.rb
SET.call(@ch[t], pos[0] * TILE_UNITS, pos[1] * TILE_UNITS, type_vol(t), 1)
```

### Canales

`CHANNEL_FILES` es la lista `[símbolo, fichero, 1 si es bucle]` que `boot` recorre entera, y la respuesta a "qué
fichero suena para esto": el glosario previsualiza los mismos ficheros y un test cruza ambas listas.

| Familia | Canal y fichero | Bucle |
|---|---|---|
| Emisores | `:npc` `pa3d_npc.wav`, `:object` `pa3d_object.wav`, `:door` `pa3d_door.wav`, `:teleporter` `pa3d_teleporter.wav` | no |
| Puzles | `:hazard` `pa3d_hazard.wav`, `:control` `pa3d_control.wav`, `:trap` `pa3d_boop.wav`, `:push` `pa3d_boing.wav` | no |
| Marcadores | `:mark` `pa3d_mark.wav` — los marcadores del jugador; casillas, no eventos, así que `rescan` los añade aparte (`mark_emitters`) | no |
| Choques | `:wall` `pa3d_wall.wav` (terreno), `:interact` `pa3d_interact.wav` (algo interactuable) | no |
| Ambiente | `:water` `pa3d_water.wav`, `:wind_w/e/n/s` `pa3d_wind_<lado>.wav` (una grabación por lado) | **sí** |
| Pasos | `:step` `pa_step.wav`, `:grass` `pa_grass.wav`, `:fstep_water` `pa_water.wav` | no |
| Guía | `:guide` `pa_guide_c.wav` | no |

### Modos de `sound_nav`

| Modo | Qué suena | Cómo |
|---|---|---|
| `:full` | todo el paisaje | pings, bucle de agua, un viento por pared, pasos y choques |
| `:basic` | solo pasos y choques, y siguen paneados | el motor sigue vivo; `tick` llama a `silence_emitters` cada frame |
| `:off` | nada | `tick` sale **antes** de `boot`, el motor ni arranca; `Spatial` tampoco toca sus cues planos |

`footstep(kind, vol)` centra el paso en el jugador y `bump(dir, interact)` suena en la casilla contra la que se
chocó. `guide(dir, vol)` coloca el chime `guide_distance` casillas hacia el siguiente paso (mínimo 1); solo lo
limita `@ready`, así que suena en `:basic`, y solo lo usan izquierda y derecha (delante y detrás, que la HRTF
no coloca, van con cue plano y el tono de pista).

### El tick

`tick` corre desde un `frame_hook` sobre `Game_Player#update`:

1. Sin `$game_map`/`$game_player`, o con `sound_nav :off`: `silence_all` y salir.
2. `boot`, una sola vez; el primer frame tras arrancar relanza `$game_map.autoplay`: abrir el dispositivo
   enmudece el BGM del juego.
3. `Spatial.busy_reason` (mensaje, menú, combate, escena ajena, ruta forzada, intérprete): `silence_all` y
   `@scan_pos = nil`, para que el paisaje se reconstruya al volver aunque el jugador no se haya movido.
4. Volumen maestro y aire, solo si cambiaron; `PA3D_Listener` sobre el jugador. En `:basic` termina aquí.
5. Solo al cambiar `[x, y, map_id]`: `rescan` (los `NEAR_MAX` = 3 más cercanos por tipo, con `cluster`
   fusionando los contiguos de igual sprite), `update_walls`, `set_winds` y el agua; si no, `refresh_movers`
   cada `MOVER_SECONDS` (1,0 s) cuando el puzle declara movedores.
6. `ping_types`: como mucho **un** emisor por frame, el tipo más atrasado, en round-robin dentro del tipo;
   durante `PING_GAP` (0,25 s) tras un ping se retienen los candidatos a `audio3d_alt_dist` casillas o menos.

Cada paso corre aislado en `step3d`: un fallo se registra una vez (`log3d`) y los demás siguen. `gate(motivo)`
cuenta por qué calló cada frame y `gate_report` lo resume para el diagnóstico.

## Ajustes

**Rutas y guía** — filas de `SCHEMA` en `core/foundation/config.rb`; los rangos salen de `KIND_BOUNDS`.

| Clave | Defecto | Rango | Qué hace |
|---|---|---|---|
| `route_reach` | 128 | 32-1024, paso 32 | Alcance máximo (diamante manhattan) de la búsqueda y del flood |
| `astar_max` | 2500 | 1000-10000, paso 500 | Tope por nodos, el corte por defecto |
| `path_algorithm` | `:astar` | los 8 de `ALGORITHMS` | Algoritmo de búsqueda |
| `straight_routes` / `edge_relax` / `ledge_directions` / `route_cache` | off / off / on / on | on/off | Penalizar giros; tolerar el borde del mapa; respetar la dirección del salto; memoizar la pasabilidad |
| `guide_refresh` / `guide_distance` | 1 / 3 | 1-10 s; 1-6 casillas | Frescura de la ruta cacheada y a cuántas casillas va el chime |
| `auto_guide` / `auto_steps` / `hide_unreachable` | off / off / off | on/off | Arrancar el bastón y la guía paso a paso al seleccionar objetivo; ocultar los objetivos sin ruta |
| `route_auto` / `route_budget_ms` | off / 8 | on/off; 2-40 ms, paso 2 | Cortar por tiempo, y ese plazo (menú de Depuración) |

**Localizador y campo**

| Clave | Defecto | Rango | Qué hace |
|---|---|---|---|
| `hide_noninteractive` | off | on/off | Omitir los eventos decorativos sin interacción |
| `fixed_target_number` | on | on/off | Numerar los objetivos por posición fija en la lista |
| `name_items` | on | on/off | Decir qué objeto contiene una poké ball del suelo, en vez de un genérico |
| `surface_cues` | off | on/off | Anunciar el terreno bajo los pies al cambiar |
| `puzzle_assist` | off | on/off | Pistas de puzle además de la posición y el estado de cada elemento |
| `transfer_active_page_only` | on | on/off | Solo cuenta como salida la baldosa cuya página ACTIVA transfiere (menú de Depuración) |

**Lectura de menús**

| Clave | Defecto | Rango | Qué hace |
|---|---|---|---|
| `auto_detect` | on | on/off | Leer por introspección los menús sin lector propio |
| `read_help` | on | on/off | Leer la descripción de cada opción tras su nombre, donde el menú la muestra |

**Audio 3D**

| Clave | Defecto | Rango | Qué hace |
|---|---|---|---|
| `sound_nav` | `:full` | `:off` / `:basic` / `:full` | Modo del paisaje sonoro |
| `audio3d_volume` | 80 | 0-100, paso 10 | Volumen maestro del motor |
| `audio3d_npc` / `_object` / `_door` / `_teleporter` / `_mark` | 85 / 85 / 85 / 90 / 85 | 0-100, paso 10 | Volumen por tipo de emisor |
| `audio3d_water` / `audio3d_wind` | 70 / 55 | 0-100, paso 10 | Volumen de los bucles |
| `footstep_volume` / `wall_volume` / `event_volume` | 80 / 80 / 70 | 0-100, paso 10 | Pasos, choques y chime de guía |
| `audio3d_freq_npc` / `_object` / `_door` / `_mark` / `guide_freq` | 90 / 10 / 70 / 80 / 75 | 0-100, paso 10 | Cadencia de los pings y del chime |
| `audio3d_occlusion` | `:hide` | `:hear` / `:occlude` / `:hide` | Emisor tras pared (raycast `line_clear?`): igual, atenuado 80 de 100, u oculto |
| `audio3d_air` | off | on/off | Absorción del aire |
| `audio3d_wall_range` / `_wall_falloff` | 3 / 50 | 1-20 casillas; 0-100, paso 10 | Sondeo de paredes y caída del viento, `v = vol / dist ** (falloff / 50.0)` |
| `audio3d_desk_range` | 2 | 0-3 casillas | Mostradores de servicio audibles en modo `:hide`; 0 lo apaga |
| `audio3d_range` / `audio3d_alt_dist` | 12 / 5 | 1-30; 1-20 casillas | Alcance del sonar (tipo propio `:sonar`) y distancia a la que dos emisores alternan |
| `sonar_only_locatable` | off | on/off | Limitar los pings a lo que alcanzan las teclas del localizador |

Las cadencias son valores 0-100 que `PokeAccess.freq_to_seconds` traduce a un intervalo real, de 1,5 s (0) a
0,15 s (100). Los tipos de puzle toman volumen y frecuencia de `audio3d_object`.

## Referencias

- [Pathfinder](../../core/nav/pathfinder.rb), [Terrain](../../core/nav/terrain.rb),
  [Locator](../../core/nav/locator.rb), [Superficies](../../core/nav/locator_surfaces.rb), [Guía](../../core/nav/guide.rb)
- [Audio3D](../../core/audio/audio3d.rb), [Spatial](../../core/audio/spatial.rb),
  [Glosario](../../core/audio/glossary.rb), [PA3D_steam](../../native/_backend.md); estado vivo con
  `diag_pathfinder` y `diag_audio3d` (Ctrl+Alt+F9)
