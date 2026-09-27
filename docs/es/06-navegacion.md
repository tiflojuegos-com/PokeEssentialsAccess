# Navegación

Dos subsistemas orientan al jugador por el mapa: `core/nav/pathfinder.rb` calcula la ruta hasta un objetivo y
`core/audio/audio3d.rb` construye el paisaje sonoro. El Locator elige el objetivo; las guías consumen la ruta.

## Búsqueda de rutas

| Llamada | Devuelve |
|---|---|
| `find_path(tx, ty)` | Direcciones RPG (`8` `2` `4` `6`) hasta una casilla **adyacente** al destino; `[]` si ya está al lado, `nil` si no hay ruta. Una puerta que solo abre entrando por un lado se alcanza por ese lado |
| `find_path_onto(tx, ty)` | Igual, pero la ruta acaba **sobre** la casilla: una orilla desde la que surfear, un punto de buceo |
| `gated_path(tx, ty)` | Sin ruta a pie, `[pasos, paso]` hasta el primer paso asistido (un obstáculo de MO, un empuje, el botón de acción, bajarse de la bici), o `nil` |
| `surf_launch(tx, ty)` | Ruta a la orilla desde la que el agua de verdad lleva al destino, o `nil` |
| `path_to_text(path, cut = false)` | La ruta hablada ("3 arriba, 2 izquierda"), o el texto de "no hay ruta" / "al lado"; con `cut`, "no se ha podido calcular la ruta desde aquí" |
| `legs(path)` | La ruta en tramos `[dirección, casillas]`; `leg_text(leg)` habla uno |
| `trace(x, y, nivel, path)` | Dónde deja al jugador cada paso de una ruta, con los mismos movimientos que hizo la búsqueda |
| `reachable_set` | `{ pkey => true }` de casillas alcanzables, cacheado por casilla del jugador |
| `reach` | Tope de distancia manhattan configurado (`route_reach`) |

El origen es **siempre** `$game_player`: no hay parámetro de partida. Se llega con `target_reached?`
(manhattan ≤ 1), porque el objetivo típico —NPC, cartel, objeto— ocupa una casilla en la que no se entra.

```ruby
# core/nav/pathfinder.rb
def self.find_path(tx, ty)
  searching do
    approach = door_approaches(tx, ty)
    next approach_path(approach) if approach
    px = ($game_player.x rescue 0); py = ($game_player.y rescue 0)
    dist = (px - tx).abs + (py - ty).abs
    next note_cut if dist > reach
    next nil if dist > FLOOD_MIN && blocked_target?(tx, ty)
    find_path_to(tx, ty, false) || find_path_to(tx, ty, true)
  end
end
```

`searching` es el marco de toda búsqueda: un solo plazo (`with_budget`), el nivel de puente del jugador devuelto
al acabar (`with_level_kept`) y el terreno preguntado una vez por casilla (`Terrain.memoizing`). Mientras corre,
`searching?` es cierto. `blocked_target?` descarta el destino con el flood cacheado, solo más allá de `FLOOD_MIN`
(24) casillas, con el flood completo y sin `edge_relax`. Dos pasadas: sin saltos de desnivel, y con ellos si falla.

Lo que dura una búsqueda vive en un `SearchContext` (`Pathfinder.context`): el plazo, cuánto anidan las búsquedas,
el vehículo y el nivel de puente con que empezó el jugador, si las rampas del mapa están vivas, el índice de
eventos de contacto a mano y si es una búsqueda asistida y con qué obstáculos apartados. Lo abre el envoltorio más
externo (`with_budget`, `with_level_kept`, `with_gates_open` o `with_rocks_through`), las búsquedas anidadas lo
comparten y se descarta al acabar la más externa, aunque lance: nada de una búsqueda queda para la siguiente. Lo
que sí dura entre búsquedas (la memo de pasabilidad, los índices por mapa, el grafo de HPA*) tiene cada cosa su
invalidación.

Ficheros: `pathfinder.rb` es el marco (contexto, plazo, memo de pasabilidad, índices, entradas); `route_search.rb`,
las búsquedas (A* y sus variantes, el flood); `route_grid.rb`, JPS y HPA*; `route_terrain.rb`, lo que hace un
paso sobre el terreno (`step_target`: bordillos, hielo, borde del mapa, reglas de llegada); `route_events.rb`, los
eventos de contacto (`move_target`); `route_water.rb`, el agua; `route_gates.rb`, las rutas asistidas; y
`route_text.rb`, la ruta hablada.

La pasabilidad es la del juego (`$game_player.passable?`), preguntada **como si el jugador no atravesara
paredes**: los juegos encienden su `through` durante los movimientos de guion y una ruta pedida en ese momento
cruzaría la roca (`player_passable?` lo aparta y lo repone).

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

`straight_routes` suma +1 al coste de cada giro. JPS y HPA* suponen una rejilla uniforme (`uniform_grid?`), así que
en un mapa con eventos de contacto que muevan al jugador (ver abajo), con terreno que registre un juego o un plugin, o
surfeando, se usa A*. JPS además cae a A* (la marca `fallback` de su barrido, `JpsScan`) con hielo,
desniveles, recursión de más de 80 niveles o al agotar su presupuesto de pasos (`[astar_max * 8, 20000]`). HPA*
divide el mapa en clusters de `HPA_CLUSTER` (10) casillas y rutea de portal en portal hasta un sumidero sintético
(`HPA_SINK`), refinando cada salto con un A* local **vivo**: un grafo obsoleto solo produce `:fallback`, nunca
una ruta errónea. Ambos, solo en la primera pasada.

### Un paso, como lo juega el juego

`move_target(cx, cy, dir, allow_ledge, edge_relax, nivel)` es el único sitio donde se compone un paso, y lo usan
la búsqueda, el flood y la guía, así que no pueden discrepar. Devuelve un `Pathfinder::Step`: la casilla donde deja
al jugador, el nivel de puente allí, las pulsaciones que cuesta (más de una solo en un tramo) y, en un paso
asistido, su puerta. Primero `step_target` resuelve la casilla:

| Terreno | Vecino resultante |
|---|---|
| Desnivel (tag 1) | Nunca es nodo pisable: se comprueba **antes** que la pasabilidad, porque los motores modernos lo declaran pasable desde el lado alto. Cruzarlo es siempre el salto de dos casillas (`ledge_jump`), con `allow_ledge`, un aterrizaje real y el bit de paso del lado opuesto abierto (`LEDGE_OPP_BIT`; permisivo si el tileset no se puede leer) |
| Hielo (tag 12) | Donde **acaba** el deslizamiento (`ice_slide`), no la casilla contigua; tope de 200 pasos |
| Borde del mapa | Con `edge_relax`, una casilla de borde pasable vale como vecino aunque falle el paso direccional. Fuera del mapa no hay vecino, aunque el motor deje andar hacia un mapa conectado |

Después, lo que haga el evento de contacto de esa casilla (o, si el paso choca, el de la casilla contra la que
choca), leído por `core/nav/route_events.rb`:

| Efecto | Qué es | En la ruta |
|---|---|---|
| `:carry` | Una ruta de movimiento sobre el jugador sin nada alrededor: un deslizador sobre un hueco, un salto sobre un seto, una escalera diagonal, un suelo flecha | Aterriza donde le deja el movimiento. Si la página no espera a que acabe, cada casilla del camino dispara su propio evento, como en el juego: así se encadenan los suelos flecha (tope `CARRY_HOPS`) |
| `:warp` | Un traslado a otra casilla del **mismo** mapa (plantas, salas, agujeros, `pbTransferWithTransition` con coordenadas) | Aterriza en el destino |
| `:exit` | Un traslado a **otro** mapa, o uno que no se puede leer (tras una pregunta) | Nunca se pisa a mitad de ruta; solo puede ser el destino |
| `:barrier` | Una escena que habla y empuja al jugador atrás o a un lado, sin cambiar nada que dure: un bloqueo de historia | Pared desde ese lado mientras dure su página |
| `:ramp` | Una rampa de puente (`pbBridgeOn` / `pbBridgeOff`) | Cambia el nivel de puente de la búsqueda |
| `:run` | Un tramo de pulsaciones fijo armado al pisar la casilla (el extremo de una escalera lateral) | Desde ella, un solo paso de la búsqueda que cuenta todas sus pulsaciones |
| `:hold` | Suelo que la página deja pisar solo con la tecla de dirección pulsada: su condición lee `Input.press?` y la rama que toma depende de ello (los suelos agrietados de Emerald, en bici) | Un paso normal; las guías dicen que se mantenga la tecla (`held_key_at?`) |

Si el evento salta al **pisarlo** o al **chocar** con él lo decide el propio `over_trigger?` del motor: un evento
sin gráfico (o con Through) sobre una casilla en la que cualquiera puede estar se pisa; sobre una casilla sólida salta
por choque desde la vecina, en las dos eras. Un evento `size(w,h)` ocupa y dispara todas sus casillas.

`core/nav/event_pages.rb` lee la página **activa** como la correría el intérprete, para cada orientación de
entrada, sin ejecutar nada: sigue las ramas `111/411/412` (la del "si no" incluida), entra en los eventos
comunes (`117`) y simula la ruta (pasos, diagonales, adelante/atrás, saltos con su distancia, giros, dirección
fija). Las condiciones se responden con el estado vivo (interruptores, variables, interruptores locales, la
orientación, la tecla pulsada) y una pequeña gramática de scripts (`$PokemonGlobal.bicycle`, la bolsa, `pbGet`,
`visitedMaps`, `$game_map.map_id`, `get_character(0)` y `(-1)` del intérprete, `&&`, `||`, `!`, comparaciones, con
cortocircuito sobre lo desconocido). Una página que pregunta dónde está el
jugador (`$game_player.x`, `.y`: las franjas de escena que lo mueven de un modo u otro según la casilla que
pisó) se lee casilla a casilla, desde donde estaría el jugador al dispararse. Lo que no sabe responder no lo
adivina: la página queda como desconocida.

### Puentes: dos niveles

Un mapa con puente son dos mapas superpuestos: el tablero, pisable con el nivel de puente arriba, y el suelo de
debajo a nivel 0. El estado de la búsqueda es `(x, y, nivel)` (`skey`), arranca en la altura de puente del motor
(`Terrain.bridge_height`: `$PokemonGlobal.bridge` desde la v16, `$PokemonMap.bridge` en las copias anteriores) y
solo cambia al pisar una rampa. Antes de expandir un nodo se pone el motor en su nivel (`use_level`), y
`with_level_kept` devuelve el del jugador al terminar, pase lo que pase. En mapas sin rampas no se toca nada.

### Agua

Sin ruta a pie, `surf_plan` repite el flood dejando surfear (`water_step`): embarcar solo desde una orilla cuya
propia casilla está abierta hacia el agua (la regla del motor), agua con agua, y desembarcar en tierra abierta
por ese lado y sin nada sólido encima; una cascada se baja desde su cresta y se sube con Cascada si el
equipo puede. Cada casilla recuerda el **primer** embarque
de su camino, y el del destino es la orilla a la que llevar al jugador (`surf_launch`), no la más cercana en
línea recta, que a menudo es un estanque que no lleva a ninguna parte. No se propone si se sabe que el equipo no
puede surfear (`FieldMoves.can?(:SURF) == false`) ni en un mapa de bici obligatoria, donde el motor lo niega.

`FieldMoves.can?` responde como el juego: el buscador propio del motor (`get_pokemon_with_move` /
`Kernel.pbCheckMove`, que comparan ids y no nombres ingleses), los objetos que declara un perfil
(`field_move_item`: Montura Surf en Z, tabla y equipo de buceo en Infinite Fusion, las apps del PokeGear de
Soulstones, que además piden la medalla), los HM Items de Marin, el
plugin Advanced Items (su propio `pbCanUseItem`) y la medalla. `nil` (no se pudo leer) nunca cuenta como no.

### Rutas asistidas

Sin ruta a pie, `gated_path` busca otra vez permitiendo lo que el jugador puede **hacer** para pasar
(`with_gates_open`), y corta la ruta antes del primer paso de ese tipo; en un mapa sin nada de eso
(`assist_possible?`) devuelve `nil` sin buscar. Cada uno lleva su puerta (`gate`):

| Paso | Qué es | La guía dice |
|---|---|---|
| Árbol de Corte, roca de Golpe Roca | `GATES`, por el nombre que ya reconoce el localizador; se ponen en `through` durante la búsqueda y la caché de pasabilidad no guarda nada mientras | "Árbol cortable arriba, usa Corte" o "necesitas Corte" |
| Roca de Fuerza, carro o estatua | Eventos cuyo script empuja (`pbPushThisBoulder`, `pbPushThisEvent`, `pbMoverEstatuas`) o llamados Boulder. Si la ruta asistida no llega, `push_route` busca a la vez al jugador y dónde deja cada roca movida (solo las movidas; la que corta el camino, tantos empujes como haga falta, o con la ayuda de puzles, `puzzle_assist`, hasta `PUSH_LIMIT` rocas; como mucho `PUSH_NODES` estados), con las rocas en `through` para el motor; un empuje vale si nada ocupa el destino y la propia roca podría moverse desde donde está (`passable?` estricto o `passableStrict?`, preguntado con su `through` apagado) | "Roca de fuerza arriba, usa Fuerza"; sin movimiento, "se empuja caminando hacia allí" |
| Botón de acción | Eventos de acción cuya página, respondiendo **sí** a su pregunta, lleva al jugador con Through (escaladas con equipo, Montura Gogoat de Z, trepar en Royal, ascensores) o lo traslada dentro del mismo mapa. Se leen con `EventPages` en modo interacción: la primera opción de cada pregunta, las confirmaciones aceptadas y la respuesta guardada en variable. Nada que combata o cambie algo que dure | "arriba: mira hacia allí y pulsa acción" |
| Cascada | Surfeando, mirando arriba contra la caída: hasta la primera casilla por encima que no es cascada ni cresta | "Cascada arriba, usa Cascada" |
| Bajarse de la bici | Hierba alta o hielo donde la bici no entra (la pasabilidad del propio motor, preguntada a pie). Nunca en un mapa de bici obligatoria (`MapMeta.always_bicycle?`) | "derecha: bájate de la bici y sigue hacia allí" |
| Lo que añade un juego o plugin | `assist_source` (DSL `assisted_step`): Treparrocas de Añil sobre la roca escalable, Treparrocas de Infinite Fusion sobre un saliente (con equipo de escalada), subir a los raíles de IF Hoenn en bici | según su etiqueta |

Un paso asistido cuesta `GATE_COST` (8) pasos más que uno normal: se prefiere un rodeo corto y un obstáculo a
dos. En el modo interacción, `EventPages.outcome(ev, d, at, true)` elige la primera opción de `102`/`402`, toma
`pbConfirmMessage` por sí y anota la respuesta de `$game_variables[n] = pbMessage(..., [opciones])`.

### Terreno que mueve al jugador

`step_target` pasa cada llegada por `arrive`: la bajada de cascadas del motor (surfeando, al entrar en la cresta
hacia abajo) y las reglas que registra el dueño de cada terreno (`arrival_rule`, DSL `terrain_rule`), porque los
números de etiqueta chocan de un juego a otro:

| Terreno | Dónde | Regla |
|---|---|---|
| Deslizamiento y corrientes (etiquetas con `slide_up`...) | Plugin Directional Sliding (Soulstones 2) | Sigue en la dirección de la casilla mientras pueda moverse y pise suelo deslizante o hielo; una casilla deslizante en el camino lanza su propio deslizamiento y, al acabar, el primero sigue si puede |
| Baldosas giratorias (`PBTerrain::SpinTile*`) | Plugin Spin Tiles (Ópalo, Realidea) | Gira hacia donde apunta la flecha y sigue, también fuera de las flechas, hasta chocar; cada flecha lo gira. La copia de Realidea para además en suelo liso del mapa 323 (`extra_stop?`, con `override`) |
| Corriente (`waterCurrent`, etiqueta 6) | Infinite Fusion e IF Hoenn | Surfeando, empuja arriba, si no izquierda, derecha o abajo, mientras siga en la corriente y pueda ir por donde entró |
| Pendiente 42 y corrientes 44-47 (con el interruptor 182) | Realidea | Tras cada paso del jugador sobre ella, una casilla abajo (o en la dirección de la corriente), con Through |
| Trampa de suelo (etiqueta 17) | Awakening | Tras cada paso sobre ella, una casilla abajo salvo que se mantenga derecha, izquierda o arriba: andando por encima se queda, bajando se cae hasta el final. Las guías dicen "mantén pulsada la tecla" (`held_key_rule`) |

Algunos terrenos se **dejan** con un movimiento propio: `leave_rule` (DSL `terrain_exit`) responde por dónde sale
el jugador aunque la casilla siguiente no lo permita, como el salto al bajar de los raíles de IF Hoenn.

Las **escaleras laterales** de Marin (plugin en Añil y Royal, y su original v17 en Realidea) son eventos `Slope` a
una casilla de cada extremo: pisarlo arma la escalera, y desde ahí `|A|` pulsaciones de lado cruzan lo que digan
las casillas y dejan al jugador `B` filas arriba o abajo. Para la ruta es un **tramo** (`:run`, registrado con
`touch_source`): un solo paso de la búsqueda que cuenta `|A|` pulsaciones, que `trace` reproduce casilla a casilla
marcando las intermedias (`mid`). Las escaleras de Royal por evento común (`Escaleras size(3,3)`) preguntan con funciones
propias dónde está el jugador respecto al evento; el perfil las declara (`script_condition`) y se leen casilla a
casilla.

Un deslizamiento por hielo que pasa por encima de un evento lo dispara como si se pisara: el hielo quebradizo
cede, un agujero lo deja caer, y un deslizamiento que cruzaría una salida no se toma. La casilla donde acaba no
pasa por `arrive`: el plugin de SS2 arrancaría ahí, pero las giratorias de gen-6 ignoran los pasos dados
deslizándose, y en ninguno de los 16 juegos en que se comprobó hay hielo junto a ese terreno.

### Cachés y presupuesto

`$game_player.passable?` es caro y una búsqueda lo llama miles de veces. Con `route_cache` se memoiza por
`vehicle_state` (el mapa y si se surfea, bucea o va en bici, en un solo entero), con la casilla, la dirección y el nivel de puente en la clave. Al empezar
cada búsqueda, `sync_event_memo` compara los eventos con los de la anterior: de uno que se movió, se volvió
atravesable o sólido o cambió de gráfico (un NPC que pasea, una roca empujada, lo que revela la Lente de la
Verdad) olvida los pasos hacia su casilla vieja y la nueva, y si además es de acción o de contacto y cambió de
página, tira los índices de lo que hacen los eventos a una ruta. No se memoiza nada con los obstáculos apartados ni con el
jugador a mitad de una escalera lateral (`on_middle_of_stair?`: el plugin de Marin responde entonces con la
escalera para cualquier casilla; tampoco se rehace el flood ni la ruta de la guía). En el extremo, con la
escalera armada pero sin subir, las respuestas son las del mapa. `invalidate_cache(force = false)` tira pasabilidad,
alcanzables, grafo de HPA*, flood de agua, ruta de surf, índices de eventos de contacto, de acción, de obstáculos y de objetos empujables;
va throttleada a 2 s, y `Caches` la registra con `force = true` (sin throttle) para el cambio de mapa y la carga
de partida. Los índices de eventos se construyen por `vehicle_state`, porque una página puede preguntar si se va
en bici; una búsqueda lo toma al empezar (`index_vehicle`), porque los consulta miles de veces. Cada vez que se tiran se cuenta (`event_epoch`, con el estado de vehículo): la guía no se fía de una
ruta guardada que se planeó con otra cuenta, la reproduce y exige que siga acabando donde se planeó; si no,
busca otra.

El terreno tiene su propio memo (`Terrain.memoizing`): dentro de una búsqueda cada casilla se pregunta al motor
una sola vez, con el estado del puente en la clave. Con `route_cache` el memo dura el mapa entero
(`Terrain.map_memo`): de ahí leen también el anillo de agua del sonar y la búsqueda siguiente, y lo tiran las
mismas cosas que la caché de pasabilidad (mapa nuevo, fin de evento, apagar la caché). Con la caché activa el
sonar tampoco reescanea en cada casilla de un deslizamiento por hielo, solo donde para (`Audio3D.slide_hold?`).

`flood` es un BFS con la expansión de la búsqueda (saltos permitidos, eventos de contacto, `edge_relax` en
false), acotado por `reach`, 10 000 nodos (20 000 con agua) y el mismo plazo; devuelve `[casillas, completo]`.
Si se corta, `blocked_target?` deja de rechazar nada. `reachable_set` lo cachea por `[x, y, map_id]` y lo
comparten `hide_unreachable`, la lista de superficies y el sonar.

Por defecto la búsqueda corta por **nodos** (`astar_max`, 2500); con `route_auto` corta por **tiempo**
(`route_budget_ms`, 8 ms) y `over_budget?` mira el reloj cada `BUDGET_CHECK` (256) nodos. El plazo es uno por
**llamada a `find_path`**, no por búsqueda: las hasta tres que puede lanzar una ruta lo comparten y anidar
`with_budget` conserva el de fuera. Lo respetan todas salvo el A* local de `hpa_low`. Agotado el plazo, aún se
devuelve una **ruta parcial** si el mejor nodo quedó a 2 casillas o menos del destino.

### Las dos guías

Las dos consumen la MISMA ruta cacheada -- `refresh_guide_path` la calcula una vez y `advance_guide_path` la
va gastando conforme el jugador anda, reproduciéndola con `trace` -- y se diferencian solo en lo que emiten:

| Guía | Tecla | Emite | Cadencia |
|---|---|---|---|
| Bastón (`toggle_guide`) | Mayús+I | Chime panoramizado hacia el siguiente paso; sobre suelo donde hay que mantener la tecla, ese mismo sonido continuo | Reloj (`guide_freq`), se espacia con la distancia; en un tramo con ese suelo, también casilla a casilla |
| Paso a paso (`toggle_steps`) | Ctrl+I | El tramo actual hablado, "6 arriba" | Al cambiar de casilla, y solo si el tramo es nuevo |

`Pathfinder.legs` parte la ruta en tramos `[dirección, casillas]`: `path_to_text` los une todos (tecla I) y
`announce_leg` lee solo el primero. Habla cuando cambia la dirección, o cuando el mismo tramo se ALARGA tras
un desvío; mientras solo encoge, calla. Antes de un paso que es un salto (desnivel o evento que salta) dice
"salta" y la dirección. Comparten el pestillo de "sin ruta" y el final del trayecto (`stop_guides`), así que
llegar no se anuncia dos veces aunque las dos estén encendidas. A mitad de un tramo (una escalera lateral) la
guía sigue en la ruta sin gastar nada hasta que el tramo acaba. Donde hay que mantener la tecla pulsada, la
paso a paso lo dice con el tramo y el bastón una vez, antes de su siguiente paso sobre ese terreno (si las
dos están encendidas, solo la paso a paso). Con el audio 3D el bastón cambia además el chime por ese mismo
sonido sostenido (`:guide_hold`, un bucle que se mueve sin reiniciarse) mientras su siguiente paso cae en ese
suelo, y en un tramo que lo cruza sigue al jugador casilla a casilla. La comprobación rehace el tramo como lo
hizo la búsqueda, así que un paso que el terreno lleva más allá se juzga donde acaba.

Los pasos que dicen las guías son pasos de movimiento. Al cambiar de dirección, o al soltar y volver a pulsar,
la primera pulsación breve solo gira al personaje (el motor espera más de 2 fotogramas en gen-6 y 0,075 s en
v21 antes de dar el paso); manteniendo la tecla no se nota.

Sin ruta a pie, la guía prueba primero la ruta asistida y después la de la orilla. En los dos
casos el final de la ruta **no** es la llegada: las guías siguen encendidas y dicen una vez por casilla qué
hacer ahí ("Árbol cortable arriba, usa Corte", "arriba: mira hacia allí y pulsa acción", "surfea derecha"); en cuanto el jugador
lo hace, la ruta nueva existe y siguen solas. En un punto de buceo la ruta acaba encima y dice qué hace el botón
de acción; uno elegido a pie espera antes en la orilla diciendo hacia dónde surfear. Mientras un evento arrastra al
jugador (un deslizamiento, un teletransporte), la guía por pasos calla y vuelve a hablar desde donde aterriza.

## Categorías del localizador

Shift + flecha cambia de categoría; la flecha sola recorre la lista, ordenada por distancia. El nombre
hablado sale de la clave `tcat_*` correspondiente.

| Símbolo | Qué lista |
|---|---|
| `:all` | Todo lo alcanzable con las teclas: sprites de personaje y eventos examinables |
| `:people` / `:objects` | El reparto de `event_category`: quien se mueve o habla, y lo demás |
| `:exits` | Transferencias de mapa, con las puertas anchas colapsadas en una sola. Se nombran "salida a X", o "entrada a X" de exterior a interior (metadatos del mapa); si el destino se llama igual que el mapa actual, "Centro Pokémon" (el mapa declara su punto de curación), "edificio" u "otra parte de X" |
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
| Guía, mantén pulsada la tecla | `:guide_hold` `pa3d_guide_hold.wav` — el timbre del chime (Mi5 y sus armónicos 2.º y 3.º), sostenido | **sí** |

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
3. `Spatial.busy_reason` (mensaje, menú, combate, escena ajena, la actualización reducida del mapa, ruta
   forzada, intérprete): `silence_all` y
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
| `straight_routes` / `edge_relax` / `ledge_directions` / `route_cache` | off / off / on / on | on/off | Penalizar giros; tolerar el borde del mapa; respetar la dirección del salto; memoizar la pasabilidad y el terreno del mapa, y no reescanear el sonar a mitad de un deslizamiento |
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
| `defer_target_rebuild` | on | on/off | Al acabar un evento, la lista de objetivos se marca vieja y se rehace al usarla (J/L o dónde está) en vez de en ese momento (menú de Depuración) |

**General**

| Clave | Defecto | Rango | Qué hace |
|---|---|---|---|
| `language` | `:auto` | `:auto`, o un código con fichero en `lang/` | Idioma de la voz del mod. `:auto` toma el del sistema (catalán, euskera y gallego cuentan como español); si el mod no lo tiene, el que declara el juego; si tampoco, inglés. Al actualizar desde una versión anterior el ini pasa a `auto` una sola vez (`settings_version`); después la elección del menú se conserva |

**Lectura de menús**

| Clave | Defecto | Rango | Qué hace |
|---|---|---|---|
| `auto_detect` | on | on/off | Leer por introspección los menús sin lector propio |
| `read_help` | on | on/off | Leer la descripción de cada opción tras su nombre, donde el menú la muestra |
| `dialogue_pages` | off | on/off | Leer los diálogos página a página según los muestra el cuadro, cortando la anterior al avanzar, en vez del mensaje entero en cola (`core/dialogue/pages.rb`) |

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
| `game_bump` | off | on/off | Dejar sonar también el choque del propio juego; apagado, mientras el aviso de pared del mod esté activo solo suena el del mod |

Las cadencias son valores 0-100 que `PokeAccess.freq_to_seconds` traduce a un intervalo real, de 1,5 s (0) a
0,15 s (100). Los tipos de puzle toman volumen y frecuencia de `audio3d_object`.

## Referencias

- [Pathfinder](../../core/nav/pathfinder.rb), [Terrain](../../core/nav/terrain.rb),
  [Locator](../../core/nav/locator.rb), [Superficies](../../core/nav/locator_surfaces.rb), [Guía](../../core/nav/guide.rb)
- [Audio3D](../../core/audio/audio3d.rb), [Spatial](../../core/audio/spatial.rb),
  [Glosario](../../core/audio/glossary.rb), [PA3D_steam](../../native/_backend.md); estado vivo con
  `diag_pathfinder` y `diag_audio3d` (Ctrl+Alt+F9)
