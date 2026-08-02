# Pathfinding - Búsqueda de Rutas

## Concepto: Navegación Asistida

Essentials no expone un buscador de rutas. `core/nav/pathfinder.rb` implementa el suyo sobre las casillas
transitables del mapa: A* con montículo binario y heurística Manhattan, variantes JPS y HPA*, saltos de
ledge, deslizamientos de hielo y un flood de alcanzables.

El flujo de usuario es: el Locator lista objetivos (`rebuild_targets` → `step`/`cycle_category`), el jugador
fija uno con `select_current`, y la guía por frame (el chime direccional, `core/nav/guide.rb`) consume la
ruta que devuelve el pathfinder.

## Piezas base

```ruby
module PokeAccess::Pathfinder
  # (x,y) -> un único Integer, clave de hash O(1). Para deshacerlo se divide, inline (no hay unpack):
  # x = k / PKEY_STRIDE ; y = k % PKEY_STRIDE
  PKEY_STRIDE = 100000
  def self.pkey(x, y); x * PKEY_STRIDE + y; end

  DIRS = [[0, -1, 8], [0, 1, 2], [-1, 0, 4], [1, 0, 6]]   # [dx, dy, código de dirección RPG]

  # Distancia (manhattan) a partir de la cual find_path usa el flood cacheado como rechazo rápido;
  # más cerca, un A* directo sale más barato que floodear.
  FLOOD_MIN = 24
end
```

## API pública

```ruby
# La ruta hasta una casilla ADYACENTE al destino, como lista de direcciones, o nil si no hay.
# Toma SOLO el destino: el origen es siempre $game_player.
path = PokeAccess::Pathfinder.find_path(target_x, target_y)

PokeAccess::Pathfinder.path_to_text(path)   # "3 arriba, 2 izquierda" / "no hay ruta" / "al lado"
PokeAccess::Pathfinder.reachable_set        # { pkey => true } alcanzables, cacheado por casilla
PokeAccess::Pathfinder.surf_launch(tx, ty)  # ruta a la orilla desde la que surfear, o nil
PokeAccess::Pathfinder.reach                # el tope de distancia configurado (route_reach)
```

`find_path` hace tres cosas antes de buscar:

1. Corre dentro de `with_bridges`, que fuerza la pasabilidad de los puentes para poder cruzar uno al que el
   jugador está a punto de subir (fuera de él, el motor declara sus casillas impasables). Los bits de paso
   del propio puente siguen bloqueando los lados de agua, así que nunca rutea al agua.
2. Si el destino está a más de `FLOOD_MIN`, lo descarta con `blocked_target?` (consulta el flood cacheado);
   así la guía no lanza un A* completo cada refresco apuntando a algo inalcanzable.
3. Intenta primero una ruta **solo andando** (`find_path_to(tx, ty, false)`) y solo si no existe permite
   saltos de ledge (`find_path_to(tx, ty, true)`): un salto es incómodo y a menudo de ida sin vuelta.

Toda búsqueda termina con el mismo criterio, `target_reached?`: basta con estar **encima o ortogonalmente
adyacente** al destino, porque el objetivo típico (un NPC, un cartel, un objeto) ocupa una casilla en la que
no se puede entrar.

## Algoritmos

`path_algorithm` elige el frontier; la expansión de vecinos y el desempate por menos giros son comunes.

```ruby
ALGORITHMS = [:astar, :weighted, :greedy, :dijkstra, :bfs, :dfs, :jps, :hpa]
```

| Valor | Frontier | Nota |
|---|---|---|
| `:astar` (defecto) | montículo, `f = 2g + 2h` | ruta óptima |
| `:weighted` | montículo, `f = 2g + 3h` | explora menos, la ruta puede no ser la más corta |
| `:greedy` | montículo, `f = 2h` | directo al objetivo, propenso a rodeos |
| `:dijkstra` | montículo, `f = 2g` | óptimo sin heurística, explora más |
| `:bfs` / `:dfs` | cola / pila | sin montículo; DFS solo para experimentar |
| `:jps` | Jump Point Search | ver abajo |
| `:hpa` | jerárquico por clusters | ver abajo |

Los pesos van **doblados** (`[2,2]` en vez de `[1,1]`) para que `:weighted` exprese 1,5x la heurística en
enteros puros; un peso float rompería el orden entero del montículo. Un valor desconocido cae a `:astar`.

`straight_routes` suma +1 al coste de cada giro, así la ruta prefiere tramos rectos.

## Vecinos especiales

`step_target` resuelve a qué casilla puede entrar la búsqueda desde una dirección, y es donde viven las
reglas del terreno:

- **Ledges**: una casilla de ledge NUNCA es un nodo pisable. Cruzarla es siempre el salto de dos casillas
  (`ledge_jump`, solo con `allow_ledge`), que exige un aterrizaje real y respeta la dirección:
  `ledge_dir_ok?` lee el byte de paso del tileset y solo salta si el lado opuesto está abierto. Con
  `ledge_directions` en false, o si la tabla no se puede leer, es permisivo (nunca bloquea de más).
- **Hielo**: al entrar en hielo el jugador sigue deslizándose en la misma dirección hasta salir de él o
  chocar (`ice_slide`), así que el nodo vecino es **donde acaba el deslizamiento**, no la casilla contigua.
- **Deslizadores ("minihuecos")**: eventos sin gráfico que, al pisarlos mirando en cierta dirección, mueven
  al jugador por una ruta forzada. `slide_index` los indexa por mapa (`pkey => { dirección => destino }`) y
  la búsqueda "los monta" en vez de detenerse en el hueco que cruzan.
- **Borde del mapa**: con `edge_relax`, una casilla del borde pasable cuenta como vecino aunque el paso
  direccional falle (ahí viven las conexiones entre mapas).

```ruby
# Dirección del salto => bit de paso del lado OPUESTO, el que ledge_dir_ok? exige abierto.
LEDGE_OPP_BIT = { 2 => 0x08, 8 => 0x01, 4 => 0x04, 6 => 0x02 }
```

## Caché de pasabilidad

`$game_player.passable?` es caro y la búsqueda lo llama miles de veces. Con `route_cache` (por defecto ON)
se memoiza por `[map_id, surfing, diving]`:

```ruby
def self.passable_at?(cx, cy, d)
  return ($game_player.passable?(cx, cy, d) rescue false) unless Config.route_cache
  st = [$game_map.map_id, $PokemonGlobal.surfing, $PokemonGlobal.diving]
  if @pcache_state != st; @pcache_state = st; @pcache = {}; end   # cambió el estado: tirar la caché
  k = pkey(cx, cy) * 16 + d                                       # una clave por casilla y dirección
  v = @pcache[k]
  v.nil? ? (@pcache[k] = ($game_player.passable?(cx, cy, d) rescue false)) : v
end
```

La caché **no** sigue los eventos que se mueven; por eso es un ajuste que el jugador puede apagar.

### Invalidación

```ruby
def self.invalidate_cache(force = false)
  now = (PokeAccess.clock rescue 0)
  # Throttle: una escena dispara muchos fines de evento seguidos y cada re-flood en frío cuesta.
  return if !force && @last_invalidate && (now - @last_invalidate) < 2.0
  @last_invalidate = now
  @pcache = {}; @pcache_state = nil   # pasabilidad
  @rs_key = nil                       # conjunto de alcanzables (se re-floodea)
  @hpa = nil; @hpa_sig = nil          # grafo abstracto de HPA*
  @surf_key = nil; @surf_route = nil  # ruta de surf cacheada
  @slide_key = nil                    # índice de deslizadores
end
```

Se llama al terminar un evento del mapa (un interruptor pudo abrir o cerrar un paso). `Caches` la registra
con `force = true` para el cambio de mapa y la carga de partida, saltándose el throttle.

## JPS (Jump Point Search)

Un A* cuyos sucesores son "puntos de salto": el siguiente giro o el objetivo en esa dirección, así que un
pasillo recto cuesta una sola expansión. Óptimo en una rejilla uniforme de 4 vecinos. Hielo y deslizadores
rompen esa uniformidad, y también un presupuesto de pasos agotado o una recursión de más de 80 niveles:
cualquiera de los tres levanta `@jps_fallback` y el llamante cae a A* normal. Los ledges son impasables
aquí (de ellos se ocupa la segunda pasada de A*). Devuelve la ruta, `nil` (fuera de alcance) o `:fallback`.

## HPA* (jerárquico)

Para mapas grandes: el mapa se divide en cuadrados de `HPA_CLUSTER` (10) casillas de lado, se abren portales
en las aberturas entre clusters vecinos y se rutea de cluster en cluster.

- `HPA_CLUSTER = 10` — lado del cluster en casillas.
- `Pathfinder.hpa_graph` — construye (y cachea por `[map, surfing, diving]`) el grafo abstracto: nodos
  portal, aristas entre clusters (coste 1) y aristas internas resueltas con un A* local acotado por cluster.
- `Pathfinder.hpa_arrivals(tx, ty)` — las casillas a las que la ruta puede LLEGAR: el destino y sus vecinos
  ortogonales, quedándose solo con las pisables. Es la forma "en grafo" de `target_reached?`.
- `Pathfinder.hpa_search(tx, ty)` — conecta origen y llegadas a los portales de su cluster, corre A* sobre
  el grafo abstracto hasta un sumidero sintético (`HPA_SINK`) enlazado desde cada llegada, y refina cada
  salto abstracto en pasos reales con un A* local **vivo**: por eso un grafo cacheado obsoleto solo puede
  producir `:fallback`, nunca una ruta errónea. Devuelve la ruta, `nil`, `:fallback` o `[]` (ya adyacente).
- `Pathfinder.hpa_low(sx, sy, gx, gy, maxnodes, x0, y0, x1, y1)` — A* de bajo nivel entre dos casillas
  exactas, acotado por caja y por nodos. Trata hielo y deslizadores como muro, de ahí el fallback.

## Alcanzables (flood)

`reachable_tiles` es un BFS desde el jugador que devuelve `{ pkey => true }`, con la **misma expansión que
la búsqueda** (`step_target`, con saltos de ledge permitidos y deslizadores montados), acotado por `reach`,
por un tope duro de 10.000 nodos y por el mismo presupuesto temporal. Si se corta deja `@rs_full` en false,
y `blocked_target?` solo rechaza un destino cuando el flood está **completo**.

`reachable_set` lo cachea por `[x, y, map_id]` del jugador, así el flood corre una vez por movimiento y lo
comparten el filtro `hide_unreachable` del Locator y la línea de vista del audio posicional (en vez de un
A* por objetivo, que hacía tardar segundos en cambiar de categoría en un mapa grande).

Si `find_path` no llega andando (el objetivo puede estar al otro lado del agua), `surf_launch` busca en ese
mismo conjunto la casilla de orilla más cercana al destino y rutea hasta ella: dónde empezar a surfear.

## Corte por nodos vs corte por tiempo

Por defecto la búsqueda corta por **número de nodos** (`astar_max`, 2500), que en un mapa muy grande o con
un `passable?` lento puede convertirse en un pico de varios frames. Con **`route_auto` activado** corta por
**tiempo** (`route_budget_ms`, 8 ms): fija una hora límite al empezar y para en cuanto se supera,
devolviendo la mejor ruta encontrada. El tiempo es constante; lo que varía es cuán lejos llega (más en un
PC rápido, menos en uno lento).

El plazo es **uno por RUTA, no por búsqueda**, y esa distinción es la opción entera. Un `find_path` son
hasta tres búsquedas — la sonda de alcanzabilidad, la ruta a pie y la ruta que admite saltos de saliente —
y mientras cada una arrancaba su propio reloj, los 8 ms se gastaban tres veces. Lo grave no era la
aritmética: agotar el plazo hace que la búsqueda devuelva nil, y devolver nil es justo lo que **dispara la
siguiente**, así que el corte alimentaba el trabajo que existía para cortar. `with_budget` envuelve
`find_path` y todas comparten la misma hora límite; anidar conserva la de fuera, para que una búsqueda
interna no se auto-conceda presupuesto nuevo.

```ruby
BUDGET_CHECK = 256   # cada cuántos nodos se mira el reloj

def self.over_budget?(iter, deadline)
  return iter > PokeAccess::Config.astar_max unless deadline
  (iter & (BUDGET_CHECK - 1)) == 0 && (PokeAccess.clock rescue 0.0) > deadline
end
```

El mismo corte temporal se aplica a A*/las variantes de montículo, a JPS, al A* sobre el grafo abstracto de
HPA* y al flood de alcanzables. `astar_max` y `route_reach` siguen siendo topes duros, pero en modo tiempo
casi siempre corta antes el reloj. El A* LOCAL que refina cada portal de HPA* (`hpa_low`) no se limita por
tiempo: está acotado por cluster (10x10) y es barato, y el corte temporal del grafo que lo invoca ya acota
el total.

Cuando la búsqueda se agota sin llegar, todavía devuelve una **ruta parcial** si el mejor nodo visitado
quedó a 2 casillas o menos del destino.

## Configuración de usuario

```ruby
# core/foundation/config.rb -- [clave, defecto, tipo, categoría, lbl, help]
[:route_reach,      128,    :reach, :pathfinder_adv, ...]  # alcance máximo (diamante manhattan)
[:astar_max,        2500,   :astar, :pathfinder_adv, ...]  # tope por nodos (corte por defecto)
[:path_algorithm,   :astar, :algo,  :pathfinder_adv, ...]  # uno de ALGORITHMS
[:straight_routes,  false,  :flag,  :pathfinder_adv, ...]  # penaliza los giros
[:edge_relax,       false,  :flag,  :pathfinder_adv, ...]  # tolera el borde del mapa
[:ledge_directions, true,   :flag,  :pathfinder_adv, ...]  # respetar la dirección de los ledges
[:route_cache,      true,   :flag,  :pathfinder_adv, ...]  # memoizar pasabilidad
[:guide_refresh,    4,      :sec,   :pathfinder_adv, ...]  # frescura de la ruta cacheada de la guía
[:guide_distance,   3,      :gdist, :pathfinder,     ...]  # a cuántas casillas se coloca el chime
[:hide_unreachable, false,  :flag,  :pathfinder,     ...]  # ocultar objetivos sin ruta
[:route_auto,       false,  :flag,  :debug,          ...]  # cortar por TIEMPO en vez de por nodos
[:route_budget_ms,  8,      :ms,    :debug,          ...]  # ese tiempo, en ms
```

`route_auto` y `route_budget_ms` viven en el menú de Depuración: pueden cortar una ruta larga real antes de
hallarla, así que por defecto están apagados para conservar el alcance máximo.

## La guía: cadencia y salvaguardas

El chime de guía suena cada `guide_interval(dist)` (`core/nav/guide.rb`): parte de `guide_freq` y **se
espacia con la distancia** (el intervalo configurado sobre el objetivo, hasta 2x a `GUIDE_FALLOFF_TILES`
(24) o más lejos), para que un objetivo lejano no machaque el oído. Tres salvaguardas más:

- **Objetivo sin ruta**: `find_path` devuelve `nil`, pero el chime sigue sonando en línea recta hacia el
  objetivo (`noroute_cue`) para acercarte lo máximo; ese resultado se memoiza por `[posición, objetivo]`
  (`@noroute_key`), así NO se re-ejecuta el A* completo cada frame. Se descarta al moverte, al cambiar de
  objetivo, o cuando un evento termina (`Locator.forget_noroute`, junto a `invalidate_cache`).
- **Esquinas**: al girar, el jugador está a mitad de paso con `path[0]` apuntando un instante a la pared del
  giro; el recálculo forzado de "siguiente paso bloqueado" se throttlea (`RECHECK_BLOCKED_SEC`, 0,5 s) para
  no correr un doble A* por frame en cada esquina.
- **Ruta cacheada**: `follow_cached_path` la reutiliza mientras el jugador siga sobre ella; pasada la
  ventana de frescura (`guide_refresh`) la revalida con un barrido lineal, no con un A* completo.

## Diagnóstico

```
# Ctrl+Alt+F9 -> accessibility/data/diag.txt (bloque de Input.diag_pathfinder)
pathfinder: reach=128 astar=2500 algo=:astar cache=true edge_relax=false
reachable: 892 tiles, x 12..40, y 5..33
target_route: to 30,18 manhattan=14 over_reach=false find_path=17steps surf_launch=nil
  walk_only=ok target_reachable=true
  route=3 arriba, 2 izquierda
```

Con `route_auto` activo, el tope por nodos deja de ser el corte efectivo: la búsqueda para por tiempo y
devuelve la mejor ruta encontrada en ese plazo.

## Referencias

- [Pathfinder](../core/nav/pathfinder.rb)
- [Guide](../core/nav/guide.rb) - la guía (Locator, parte 4 de 4)
- [Locator](../core/nav/locator.rb) - quién elige el objetivo
- [Terrain](../core/nav/terrain.rb) - ledges, hielo, agua surfeable

## Próximo

- [Audio3D](07_AUDIO3D.md) - Sonido posicional
- [Ruby Fundamentals](08_RUBY_FUNDAMENTALS.md) - Conceptos de Ruby
