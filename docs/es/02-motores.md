# Motores

Essentials existe en versiones con APIs incompatibles y los fangames reales las mezclan.
`core/foundation/engine.rb` responde qué motor corre; todo el gateo pasa por `Engine.has?`.

## Eras

| Era | Versiones | API de datos | Escena de batalla | Jugador | Marca que la delata |
|---|---|---|---|---|---|
| gen-6 | v16–v17 | tablas `PB*` | `PokeBattle_Scene` | `$Trainer` | no existe `GameData::Species` |
| GameData transicional | v18 | `GameData::*` | `PokeBattle_Scene` | `$Trainer` | `GameData::Species` sin `Battle::Scene` |
| GameData | v19–v21.1 | `GameData::*` | `Battle::Scene` | `$player` | `Battle::Scene` |
| GameData + rework UI | v22 | `GameData::*` | `Battle::Scene` | `$player` | `UI::BaseScreen` con versión ≥ 21.9 |
| Sky (fork) | v21.1 con la UI de v22 | `GameData::*` | `Battle::Scene` | `$player` | `UI::BaseScreen` con versión < 21.9 |

Las eras se nombran por su API de datos, no por "vieja/moderna". `Engine.kind` solo distingue dos, `:gen6` y
`:gamedata`; cualquier corte más fino es una capacidad.

## Detección

`gamedata?` es exactamente `defined?(GameData) && defined?(GameData::Species)`; `gen6?` es su negación y
`kind` devuelve el símbolo. `Engine.player` resuelve `$player` o, si no lo hay, `$Trainer`. `Engine.fork` da
`:sky` con `GameData`, `UI::BaseScreen` y `version < 21.9`, y `nil` en cualquier otro caso.

`Engine.version` es un Float memoizado **solo para la línea del diagnóstico**: sondea `Essentials::VERSION`,
`ESSENTIALS_VERSION`, la estructura (con `GameData`, 19.0 si existe `Battle::Scene` y 18.0 si no),
`ESSENTIALSVERSION` parseada con suelo 17.0 —algunos forks gen-6 la escriben como texto libre— y 16.0. La era
transicional sale de la estructura y no de `$Trainer` porque en la pantalla de título el jugador aún no existe.

## Capacidades

Una capacidad es la pregunta "¿puede este motor hacer X?" resuelta contra el runtime: un lambda booleano, un
nombre de constante, o una constante más un método. Nunca un número de versión, porque los fangames mezclan
eras: así, un fork que backportea una feature se activa sin tocar el código. Las carpetas de era
([01-vision-general](01-vision-general.md)) dicen dónde apareció una capacidad, no cuándo se activa.

`Engine.has?` es la única puerta y acepta tres formas:

| Forma | Ejemplo | Comprueba |
|---|---|---|
| Símbolo registrado | `has?(:ui_rework)` | la entrada correspondiente de `CAPABILITIES` |
| `"A::B::C"` | `has?("UI::BagVisuals")` | que la constante exista, vía `PokeAccess.const_at` |
| `"Clase#metodo"` | `has?("Battle::Scene::MenuBase#setIndexAndMode")` | la constante **y** el método de instancia, público o privado |

```ruby
# core/battle/gen6/battle_g6.rb
mega_setter = ["megaButton=", "mode="].detect { |m| PokeAccess::Engine.has?("FightMenuDisplay##{m}") }
```

Cualquier excepción responde `false`, y un símbolo sin registrar también: se anota una vez con `log_once`,
porque un typo silenciaría una familia entera de lectores sin ruido ninguno.

### La tabla

| Capacidad | Probe | Qué es |
|---|---|---|
| `:gamedata` | `lambda { gamedata? }` | era GameData |
| `:gen6` | `lambda { gen6? }` | era gen-6 |
| `:sky_fork` | `lambda { fork == :sky }` | el fork Sky |
| `:ui_rework` | `"UI::BaseScreen"` | el rework `UI::` de v22 |
| `:battle_scene` | `"Battle::Scene"` | la escena de batalla de v19+ |
| `:dbk` | `"Battle#pbToggleSpecialActions"` | Deluxe Battle Kit, plugin de terceros |
| `:mui` | `"UIHandlers"` | Modular UI Scenes, plugin de terceros |

`:dbk` y `:mui` no son features del motor y no gatean nada: reabren clases que existen en los trece juegos,
así que solo un método las identifica, y se registran para que salgan en el diagnóstico. Sus lectores se atan
hook a hook con `:optional`, que aguanta una instalación parcial del plugin.

Aquí solo va lo transversal; una pantalla puntual pasa su nombre de clase a `has?` directamente, que es lo
que hacen hoy todos los gates del core. Quien consume la forma de símbolo es la lista `caps=` del
diagnóstico, que recorre `CAPABILITIES` en vez de enumerarlas ([07-diagnostico](07-diagnostico.md)).

## Nombres de clase

Era y nombre de clase son independientes. Hay juegos que traen `GameData` conservando los nombres de clase
de v16, y otros que declaran los nombres viejos como subclases vacías de los nuevos para no romper scripts
antiguos. En los dos casos las dos clases existen a la vez y enganchar la equivocada calla o duplica: por eso
la era se pregunta al motor y el nombre se resuelve aparte, en vez de deducir uno del otro.

| Método | Devuelve | Para |
|---|---|---|
| `scene_classes(*nombres)` | los que existen, quitando los que otro ya cubre por herencia o por ser la misma clase | una pantalla con varios alias no relacionados |
| `scene_class(*nombres)` | el primero de `scene_classes`, o `nil` | alias de una misma pantalla |
| `era_scene(era, propio, ajeno)` | el nombre a enganchar, o `""` | un lector escrito contra UNA API de datos |

`era_scene` deja decidir al nombre mientras solo exista uno de los dos alias, y solo desempata por era
cuando existen los dos, que es lo que produce una capa de compatibilidad. `""` no engancha nada.

```ruby
# core/party/gen6/summary_g6.rb
SCENE = PokeAccess::Engine.era_scene(:gen6, "PokemonSummaryScene", "PokemonSummary_Scene")
```

## La franja híbrida

Entre las dos eras hay juegos sobre Essentials v18: `GameData` ya dentro, pero todavía `$Trainer` y
`PokeBattle_Scene`. Nombres de clase de gen-6 con tripas modernas, que es la combinación que rompe cualquier
regla del tipo "si se llama así, entonces es de esta era".

| Punto | Qué pasa |
|---|---|
| `kind` | `:gamedata`; el proveedor de datos activo es `DataV21` (`core/data/v21/data_v21.rb`) |
| Nombres de atributo | conservan `base_damage` en vez de `power`, así que `move_power` prueba los dos con `attr_of` |
| Batalla | se enganchan por `PokeBattle_Scene`, en `core/battle/gen6/battle_g6.rb` |
| Orden de argumentos | `pbLevelUp` pasa la velocidad al final, no en cuarto lugar como en v16-17; leer el orden ajeno no calla, anuncia tres números reales bajo los nombres de estadística equivocados |
| Jugador | `Engine.player` cae a `$Trainer` |
| Pokédex | `seen?`/`owned?` en vez de los arrays de gen-6 (`core/util/player.rb`) |

```ruby
# core/battle/gen6/battle_g6.rb -- misma clase de escena, dos órdenes de argumentos
LEVELUP_MODERN_ORDER = PokeAccess::Engine.gamedata?
```

## Ruby 1.8.7

Los juegos gen-6 corren mkxp-z sobre Ruby 1.8.7 y los modernos sobre 3.x. `core/` se carga en los dos, así
que casi todo el árbol es **código dual**, y ahí una construcción de 1.9+ no avisa: da `SyntaxError` y aborta
el fichero entero. El boot lo anota y sigue, así que el síntoma no es un cierre sino un módulo que
desaparece. La exención es por RUTA: la constante `MODERN`, en `check187.py` y `check187_real.rb`, las dos.

| Exento (Ruby 3.x) | Comprobado (1.8.7) |
|---|---|
| cualquier ruta con `/v21/` o `/v22/` | el resto de `core/` y `loader/*.rb` |
| `games/anil/`, `games/royal/`, `games/relict/`, `games/emerald/`, `games/infinitefusion/`, `games/infinitefusion_hoenn/` | el resto de `games/` |
| | todo `plugins/`: un plugin de terceros puede instalarse en un fangame gen-6 |

### Prohibido en código dual

| No escribas | Escribe |
|---|---|
| `lista.map(&:name)` | `lista.map { \|x\| x.name }` |
| `->(x) { ... }` | `lambda { \|x\| ... }` |
| `obj&.metodo` | `(obj.metodo rescue nil)` |
| `v.round(2)`, `.ceil(n)`, `.floor(n)` | `(v * 100).round / 100.0` (en 1.8.7 no llevan argumento) |
| `n.clamp(0, 100)` | `[[n, 0].max, 100].min` |
| `h.dig(:a, :b)` | `(h[:a] && h[:a][:b])` |
| `lista.each_with_object({}) { ... }` | `h = {}; lista.each { ... }; h` |
| `%i[a b]`, `<<~TEXTO`, `{ clave: valor }` | `[:a, :b]`, concatenar cadenas, `{ :clave => valor }` |
| `.transform_keys`, `.transform_values`, `.then`, `.yield_self`, `.tally`, `.filter_map` | un `each` o un `map` a mano |

### Dos trampas de sintaxis y una de semántica

**Punto al principio de línea.** El punto va al final de la línea anterior: `select { ... }.` y en la
siguiente `map`. Una constante encadenada al revés mató `config_menu.rb`, y sin ese módulo el poll del mapa
reventaba cada frame.

**`rescue` colgando de un bloque.** Solo cuelga de `begin`, `def`, `class` o `module`; dentro de un `do` o
un `{` hay que abrir un `begin`.

**`return` dentro de `define_method`.** El cuerpo es un bloque, y ahí el `return` sale del método que lo
definió: va `next` (`core/menus/scene_watcher.rb`). Es sintaxis válida, así que no lo caza nada.

### Los dos verificadores

`test/check187.py` busca patrones —punto inicial, `rescue` de bloque y una lista curada de APIs de 1.9+— y no
necesita nada instalado. `test/check187_real.rb` parsea cada fichero dual con un intérprete 1.8.7 real, sin
ejecutarlo, y solo corre si lo hay en `tools/ruby-1.8.7-*/bin/ruby.exe` junto al repo o en `RUBY187`: el de
patrones solo reconoce lo que se le ha enseñado, el parser conoce toda la sintaxis del lenguaje.

```bash
python test/check187.py                       # todo el árbol
python test/check187.py core/nav/locator.rb   # solo lo que has tocado
```
