# Extender PokeEssentialsAccess: hooks, lectores, puzzles y perfiles

Esta guía es práctica: cómo **añadir accesibilidad a una pantalla nueva** sin tocar el core, usando
la DSL `PokeAccess::Game.define`. Todos los ejemplos son código real del repo. Si una pantalla custom
de un juego queda muda, este es el flujo para arreglarlo.

> Requisito previo: lee [04_PATCHING_AND_HOOKS.md](04_PATCHING_AND_HOOKS.md) (cómo funciona el motor de
> hooks por dentro, y sobre todo la guarda de reentrancia) y [02_ARCHITECTURE.md](02_ARCHITECTURE.md)
> (capas y `games/<juego>/`).

---

## 0. El flujo completo, de pantalla muda a pantalla leída

1. **Diagnostica en runtime** (no abras el `Scripts.rxdata` del juego todavía). Entra en la pantalla
   muda y pulsa **Ctrl+Alt+F9**: vuelca `accessibility/data/diag.txt` con la sección
   `runtime introspection`, que te da la clase del `$scene`, sus métodos propios, sus ivars y las
   ventanas/sprites vivos. Ahí ves **qué método se llama al mover el cursor** y **qué ivar guarda el
   índice o los datos** (sección 9).
2. **Elige el enganche**: un método que el juego llame en cada movimiento de cursor (o al abrir).
3. **Escribe el lector** en `games/<juego>/<algo>.rb` con `Game.define`.
4. **Añádelo al `manifest.rb`** del juego (orden de carga; hay un test que comprueba que ningún archivo
   quede fuera y que ninguna entrada apunte a un archivo inexistente).
5. **Usa i18n** para todo texto hablado (`PokeAccess::I18n.t(:clave)` + claves en `lang/es.txt` y
   `lang/en.txt`). Nunca hardcodees strings nuevos **en el core** (regla sin excepciones ahí).
   **Excepción formal para PERFILES de juego monolingüe**: el perfil de un juego que solo existe en un
   idioma (royal, reminiscencia, realidea, opalo, armonia, relict, pokemon_z…) puede hardcodear sus
   frases en el idioma del juego — un usuario de otro idioma vería el juego en español igualmente, y
   mantener claves que solo un idioma usará es peso muerto. Dos matices: las TRANSCRIPCIONES de
   texto/imágenes del juego (menús dibujados, leyendas) van SIEMPRE literales (replican al juego, no son
   frases del mod), y un perfil de juego multiidioma o inglés (los Infinite Fusion, awakening) usa i18n
   completo. Dentro de un mismo perfil, elige UNA de las dos vías y sé consistente.
6. **Pasa los tests** (`ruby test/run_all.rb` corre todo: specs de ambos motores, check187 y las
   comprobaciones estáticas) e **instala** al juego.

---

## 1. La DSL `Game.define`

Toda la extensión específica de un juego pasa por un bloque `Game.define("perfil")`. Cada método del
bloque es una capa fina sobre la API del toolkit (`core/foundation/game.rb`); las llamadas crudas siguen
funcionando.

| Método | Firma | Yield | Para qué |
|---|---|---|---|
| `after` | `(clase, metodo, opts = {})` | `(instancia, resultado, args)` | Correr código DESPUÉS de un método del juego |
| `before` | `(clase, metodo, opts = {})` | `(instancia, args)` | Correr código ANTES |
| `around` | `(clase, metodo, opts = {})` | `(instancia, nxt, args)` | Envolver (debes llamar `nxt`) |
| `read_on_open` | `(clase, metodo = :pbStartScene, opts = {})` | `(escena) -> texto` | Resumen hablado al abrir la pantalla, encolado |
| `override` | `(target, metodo)` | `(receptor, original, args)` | REEMPLAZAR un lector del core o un método del juego |
| `kernel` | `(fname, timing = :before)` | `(args, x)` | Función top-level (posible en `Kernel`), p.ej. `pbItemBall` |
| `screen_reader` | `(clase)` | `(ventana, indice) -> texto` | Opción enfocada de una ventana de comandos |
| `poll_each_frame` | `()` | — | Correr algo cada frame (menús con bucle propio) |
| `diag_section` | `(nombre, grupo = :scene)` | `(lineas)` | Sección propia en el volcado de diagnóstico |
| `puzzle` | `(map_id, opts)` | — | Registrar un puzzle de mapa |
| `picture_texts` | `(map)` | — | Mapear nombres de imagen → texto hablado |
| `on_picture` | `()` | `(nombre_imagen, args)` | Handler al mostrar una imagen |
| `hazard` | `(patron, label)` | — | Sprite de peligro con etiqueta + cue |
| `config` | `(clave, valor)` | — | Sobrescribir una opción para ese juego |
| `button_labels` | `(map)` | — | Renombrar botones en el menú de remap |
| `remap_extra` | `(sym, vk, label)` | — | Acción extra remapeable |

**`after`/`before`/`around` aceptan las MISMAS opciones que el core** (`opts` llega intacto al hook):

- `:optional => true` — el método falta legítimamente en algunas builds del juego: el enganche se salta
  en silencio en vez de contar como typo en `Hooks.missing`.
- `:hook_container => true` (solo en `after`) — el método es un contenedor que delega el anuncio en
  métodos hookeados que él conduce; su original corre sin la guarda de reentrancia (sección 4).

`read_on_open` acepta además `:timing => :before` para abridores que **bloquean** en su propio bucle.

**Regla de oro:** cada hook se ata por **existencia de clase/método**. Si la clase no existe en ese
juego, el hook no se registra (no-op). Por eso un perfil puede declarar lectores para clases que solo
existen en una versión, sin romper las demás.

---

## 2. El core es AGNÓSTICO (y hay un test que lo vigila)

El core **no nombra juegos**. Un lector de `core/` se ata a clases y métodos de Essentials o de un
plugin, nunca a "el juego X"; lo que solo tiene sentido en un juego vive en `games/<juego>/`.

`test/static/coupling_spec.rb` convierte esa regla de arquitectura en CI. Mapea cada módulo/clase/
constante de segundo nivel a la capa que lo DEFINE (`core` compartido, una carpeta de versión
`gen6/v21/v22/skyflyer`, o un `games/<perfil>`) y escanea el código de cada archivo (sin comentarios)
buscando referencias que crucen capas. Falla si:

| Violación | Significa |
|---|---|
| **version cross** | Una versión del core referencia un módulo de otra versión (`v21` usando algo de `v22`) |
| **profile cross** | Un perfil referencia un módulo de otro perfil |
| **shared->version** | Código compartido del core referencia un módulo de una versión concreta |
| **profile reopens core module** | Un perfil **redefine** un módulo/clase del core |

La última es la importante para un colaborador: **un perfil no reabre módulos del core en silencio.**
Si quieres cambiar lo que hace un lector del core para tu juego, la vía declarada es `override`
(sección 5) — que además queda listada en el diagnóstico. La única excepción es reabrir `Config` para
ASIGNAR constantes de ajuste, que es uso, no redefinición. Las excepciones conscientes viven en la lista
blanca del spec, con su motivo escrito.

---

## 3. Añadir un lector a una pantalla custom (el caso más común)

### 3a. Menú basado en ventanas de comandos (`Window_DrawableCommand` y similares)

Si el diag muestra la pantalla en `live_cmd_windows`, el core probablemente ya la lee por su hook
genérico de `#update`. Si no la lee bien (etiqueta equivocada), usa `screen_reader`:

```ruby
# games/<juego>/mi_menu.rb
PokeAccess::Game.define("<juego>") do
  # Yields (ventana, indice) y devuelve el texto de la opción enfocada.
  screen_reader("Window_MiMenuCustom") do |win, idx|
    cmds = PokeAccess.ivar(win, :@commands)
    cmds && cmds[idx] ? PokeAccess.clean(cmds[idx].to_s) : nil
  end
end
```

De todos los extractores registrados cuya clase encaje con la ventana, gana el **más derivado**
(imitando el dispatch de Ruby), así que un perfil puede especializar una SUBCLASE de una ventana que el
core ya cubre y su extractor gana, sea cual sea el orden de registro.

### 3b. Lector de cursor de sprite (el patrón más repetido)

Es **el caso difícil y el más común** en pantallas custom: menús "bezier", quest logs, logros, los
selectores in-battle de DBK, el selector de bendiciones de Reminiscencia, las placas Arcy de Relict...
Ninguno tiene `Window_DrawableCommand`; son `Sprite`s con el resaltado movido por `src_rect`/un sprite
cursor, y el índice en un ivar privado. El core no los ve.

**La receta, siempre la misma (tres pasos):**

1. **Engancha el método de redibujado/selección** que el juego llama en cada movimiento de cursor (y al
   abrir). Lo descubres con el diag-runtime (sección 9): busca un `selectButton`/`updateCursor`/
   `refresh`/`showTexts`/`pbUpdate*` que corra al mover.
2. **Lee el ivar del índice** y **el ivar de los datos** (la lista de entradas).
3. **Deduplica con `PokeAccess::Cursor`**, la primitiva por defecto, para no repetir la misma entrada
   cada frame pero sí volver a leer al reabrir.

```ruby
# games/relict/plates.rb -- selector de placas Arcy en combate. rewriteArcyPlates(plates, index) corre al
# abrir y en cada izq/der; el dedup vive en la Scene, que dura todo el combate, así que el abridor lo resetea.
PokeAccess::Game.define("relict") do
  before("Battle::Scene", :pbActivateArcyPlates) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :plate_idx)
  end
  after("Battle::Scene", :rewriteArcyPlates) do |scene, _r, args|
    plates = args[0]; index = args[1]
    next unless plates.is_a?(Array) && index && index >= 0 && index < plates.length
    next unless PokeAccess::Cursor.changed?(scene, :plate_idx, index)
    PokeAccess.speak_clean(nombre_de_placa(plates[index]), true)
  end
end
```

Cuando lo único que quieres es "habla la línea si cambió el foco", `Cursor.announce` lo hace de una vez:

```ruby
# updateCursor corre al abrir y en cada izq/der; @index = carta enfocada, @blessings = las cartas.
after("PickBlessing", :updateCursor) do |scene, _r, _a|
  idx  = PokeAccess.ivar(scene, :@index)
  list = PokeAccess.ivar(scene, :@blessings)
  next unless list.is_a?(Array) && idx && idx >= 0 && idx < list.length
  PokeAccess::Cursor.announce(scene, :bless, idx) { texto_de_la_carta(list[idx]) }
end
```

> **`first_interrupt` — encolar la primera lectura.** Cuando una pantalla se abre encima de una pregunta o
> título que aún suena, no quieres que la lectura de apertura lo corte, pero sí que los movimientos
> posteriores interrumpan. Pásalo como quinto argumento:
> `Cursor.announce(scene, :bless, idx, true, false) { ... }` — la PRIMERA lectura de un cursor
> fresco/reseteado (cuando el slot está `pending?`) usa `false` (encola), y cada movimiento después usa
> `true` (interrumpe).

> **`speak_clean` vs `speak`.** `PokeAccess.speak_clean(text, interrupt)` limpia los códigos de control de
> RPG Maker (`\PN`, `\V[n]`, `\C[n]`...) y habla; es la forma correcta para texto que viene del juego. Si ya
> tienes una línea limpia (una clave i18n ya resuelta), usa `PokeAccess.speak(text, interrupt)` directo.
> `PokeAccess.ivar(obj, :@x, fallback)` lee un ivar sin que un objeto raro tumbe el frame.
> `Cursor.announce` ya limpia por dentro.

> **Dedup por instancia, siempre.** El estado de dedup vive en el `holder` (la escena), así que muere con
> ella y la pantalla vuelve a leer al reabrirse en el mismo estado. Un dedup a nivel de módulo deja la
> pantalla muda al reabrirla. `Cursor` cubre además los casos sutiles: escena fresca que debe releer el
> mismo índice (`reset`/`pending?`), clave-tupla `[página, índice]`, y texto que cambió sin cambiar el
> índice (deduplica por el TEXTO como key).

> **`Cursor` es el dedup por defecto, con una excepción acotada.** Un lector nuevo usa `Cursor`. El dedup
> a mano con un ivar propio se tolera solo donde el hook **ya recibe por `args` el dato que compara** (el
> índice o la clave llegan como argumento del método enganchado, así que no hay que ir a buscarlos a la
> instancia): ahí la comparación es local al hook y el ivar solo guarda el valor anterior. Es lo que verás
> en los lectores in-battle de DBK (`core/battle/skyflyer/`). En cuanto necesites `reset`/`pending?`,
> `first_interrupt` o una clave-tupla, es `Cursor`.

> **Patrones ya empaquetados en el core**, por si tu pantalla encaja:
> `PokeAccess::SpriteButtonMenu.define("<juego>")` (menú de pausa de sprites con `selectButton`/`@buttons`:
> una línea en vez del bloque entero) y `PokeAccess::Menus.poll_sprite_menu(scene, items_ivar, slot)`
> (escena con `@index` + array de entradas: ya lee el índice, valida el rango y deduplica con `Cursor`).
> Otros ejemplos reales: `core/battle/skyflyer/dbk_selectors.rb`.

### 3c. Pantallas con su propio bucle bloqueante (`SceneWatcher`)

Si el juego corre su propio bucle de entrada (llama a `Input.update` él mismo), los hooks de cursor no
disparan a mitad y a veces la escena ni siquiera es `$scene`. `PokeAccess::SceneWatcher` sujeta la escena
viva mientras dura el método del bucle y sondea el foco cada frame:

```ruby
# games/awakening/glossary.rb -- Scene_Glosario bloquea dentro de main, así que nunca es $scene.
# El bloque devuelve [key, texto]: una key nueva habla el texto; nil salta el frame.
module PokeAccess
  AwakeningGlossary = SceneWatcher.reader("Scene_Glosario", :main, :aw_glossary) do |s|
    idx = PokeAccess.ivar(s, :@index)
    cmds = PokeAccess.ivar(s, :@commands)
    ok = idx && cmds.is_a?(Array) && idx >= 0 && idx < cmds.length
    ok ? [idx, cmds[idx].to_s] : nil
  end
end
```

`SceneWatcher.reader` resetea el dedup al abrir Y al cerrar (reabrir en la misma entrada vuelve a leer),
se auto-gatea por existencia de la clase y traga un bloque que lance (un bug de lector no puede matar el
bucle de entrada). Si tu módulo se desvía de esa figura (tiene su propio ritmo de habla o una API extra),
usa `SceneWatcher.wire(clase, metodo, lector)` con un módulo que responda a `watch(scene)`, `unwatch` y
`poll` — como hace `games/reminiscencia/bag.rb`.

Si el juego **no llama a ningún método** al mover y no hay un bucle que sujetar, queda
`poll_each_frame` (un bloque que corre una vez por frame en toda escena), gateando por clase de `$scene`.

### 3d. Resumen hablado al abrir una pantalla (`read_on_open`)

Para pantallas informativas (tarjeta de entrenador, resultados, leyendas) que solo hay que leer entera al
entrar. Habla **encolado** (una lectura de apertura nunca corta lo que suene) y limpia el texto:

```ruby
PokeAccess::Game.define("royal") do
  read_on_open("TarjetaEntrenador_Scene") { |_s| PokeAccess::RoyalTrainerCard.text }
end

# games/opalo/trainer_card.rb -- este abridor BLOQUEA en su propio bucle: con un after solo hablaría al
# cerrar la pantalla, así que se lee ANTES.
PokeAccess::Game.define("opalo") do
  read_on_open("OpaloCard", :pbStartScene, :timing => :before) { |_s| PokeAccess::OpaloCard.main_text }
end
```

---

## 4. Cuando `Game.define` no basta: contenedores y drivers por-frame

`after`/`before`/`around`/`poll_each_frame` cubren casi todo. Dos casos necesitan una opción concreta,
porque el original del método que enganchas aloja sincrónicamente OTROS lectores hookeados y un `after`
normal (que corre bajo la guarda de reentrancia) los silenciaría.

**El porqué en una frase:** el juego es mono-hilo; `Hooks` lleva una pila con el nombre del método cuyo
original está corriendo, y salta cualquier hook anidado de nombre DISTINTO (para que un `after` que llame
internamente a otro método hookeado no lo re-anuncie ni le robe el dedup). Eso está bien para un
*anunciante atómico* (su propio cuerpo es la voz), pero es fatal para un método que DELEGA el anuncio a
los lectores que conduce por dentro. Detalle completo en [04_PATCHING_AND_HOOKS.md](04_PATCHING_AND_HOOKS.md).

### 4a. `:hook_container => true` — un contenedor modal que delega el anuncio

Un bucle modal o abre-escena que no habla él mismo, sino que conduce métodos hookeados (el `drawPage` del
pokédex, el `drawPageOne` del resumen, el `selected=` del panel de party, el menú de comandos de combate).
Su original debe correr SIN la guarda o esos lectores internos enmudecen. Se pasa igual desde la DSL:

```ruby
PokeAccess::Game.define("<juego>") do
  after("MiScene", :pbStartScene, :hook_container => true) do |_scene, _r, _a|
    # normalmente vacío: el anuncio lo hacen los lectores que la escena conduce por dentro
  end
end
```

### 4b. `frame_hook` — un driver por-frame que anida un bucle modal entero

Un método que el motor llama CADA frame y que puede alojar dentro un bucle modal completo. El caso canónico
es `Game_Player#update`: en gen-6, pisar hierba lanza el combate salvaje DESDE DENTRO de `update`
(`Scene_Map#update -> $game_player.update -> encounter -> el combate entero`). Guardarlo fijaría `:update`
en la pila durante todo el combate y cada lector de batalla (mensajes, menú de comandos, movimientos) se
saltaría como anidado — el bug clásico "los combates salvajes son mudos, los de entrenador leen" (el de
entrenador corre desde el intérprete del mapa, no desde el player). `frame_hook` corre el original SIN
guarda y el cuerpo DESPUÉS (un poller que lee el estado del frame ya actualizado). No tiene entrada en la
DSL: se llama directo.

```ruby
PokeAccess::Hooks.frame_hook("Game_Player", :update) do |_player, _args|
  # poller: lee el estado ya actualizado del frame; sin valor de retorno que usar
end
```

Regla práctica: si tu `after` engancha algo que abre una escena/menú con sus propios lectores, o un método
por-frame que puede lanzar un combate/menú entero, usa `:hook_container`/`frame_hook`; para un anunciante
atómico, el `after` normal es lo correcto.

---

## 5. Reemplazar un lector del core: `override`

Cuando el core ya lee una pantalla pero tu juego necesita que la lea de otra forma, **no reabras el módulo
del core** (el spec de acoplamiento lo rechaza y nadie vería el cambio). Declara el reemplazo:

```ruby
# games/reminiscencia/move_relearner.rb -- aquí las flechas deben decir solo el nombre del movimiento;
# el detalle completo lo publica este perfil en la tecla de info.
PokeAccess::Game.define("reminiscencia") do
  override(PokeAccess::MoveRelearnerGen6, :detail) do |_mod, _original, args|
    id = (PokeAccess::MoveRelearnerGen6.focused_id(args[0]) rescue nil)
    name = id ? (PokeAccess::Data.move_name(id) rescue nil) : nil
    PokeAccess.speak(name.to_s, true) if name && !name.to_s.empty?
  end
end
```

- `target` es un **módulo del mod** (se sustituye su método de singleton) o el **nombre en string de una
  clase del juego** (se sustituye su método de instancia).
- El cuerpo recibe `(receptor, original, args)`. `original` es un lambda con la implementación
  reemplazada: **llámalo para envolver** en vez de sustituir.
- Es **apilable**: un segundo `override` sobre el mismo método recibe el primero como su `original`; gana
  el último y ambos quedan listados.
- Semántica de `around`: el fallo del cuerpo se loguea y **se relanza** (no se traga).
- Cada instalación aparece en `Hooks.overrides` y **el diagnóstico la imprime**, con el tag
  `game_<perfil>` que pone la DSL. Pisar un lector del core nunca es invisible.

---

## 6. Diagnosticar mecánicas propias del juego: `diag_section`

El core no conoce tu juego, así que tampoco puede diagnosticarlo. Un perfil contribuye su propia sección
al volcado (Ctrl+Alt+F9) y al grupo correspondiente del menú de depuración. El bloque recibe el array de
líneas de salida y hace `push`, igual que las secciones nativas, y va guardado (una sección que peta no
pierde el resto del volcado).

```ruby
# games/reminiscencia/bag.rb
PokeAccess::Game.define("reminiscencia") do
  diag_section(:reminbag) do |o|
    rb = PokeAccess::ReminBag
    s = PokeAccess.ivar(rb, :@scene)
    o.push("reminbag: watching=#{!s.nil?}")
    next if s.nil?
    win = PokeAccess.sprite(s, "itemwindow")
    o.push("  itemwindow=#{win ? win.class : 'nil'} idx=#{PokeAccess::Keys.dv { win.index }}")
  end
end
```

El segundo argumento es el grupo del menú de depuración (`:scene` por defecto; también `:audio`,
`:events`, `:perf`, `:map`).

---

## 7. Añadir un puzzle

Los puzzles se registran por mapa con `puzzle(map_id, opts)`. Hay tres tipos (`:kind`):

- **`:grid`** (por defecto) — rejillas de runas en el suelo (no resolubles a ciegas). Anuncia cada celda
  con cue paneado por columna y pitch por fila.
- **`:state`** — mecanismos cuyo progreso vive en switches/variables invisibles (grúas, válvulas).
- **`:facing`** — estatuas rotables.

Cada tipo escala con el ajuste `puzzle_assist` (apagado = el mínimo estado invisible; encendido = añade la
solución explícita).

Ejemplo `:state` (mecanismo con un switch):

```ruby
PokeAccess::Game.define("<juego>") do
  puzzle(123, {
    :kind  => :state,
    :watch => [{ :switch => 45, :label => :puzzle_crank, :on => :puzzle_up, :off => :puzzle_down }],
    :solved     => lambda { $game_switches[50] },
    :solved_msg => :puzzle_done,
    :hint       => :puzzle_hint_crank   # solo se dice con puzzle_assist activado
  })
end
```

Las claves `:label/:on/:off/:solved_msg/:hint` son **símbolos i18n** (o strings literales). Los `opts` de
cada tipo están documentados en la cabecera de `core/puzzles/puzzles.rb`; hay ejemplos reales de `:grid` en
`games/pokemon_z/puzzles.rb`.

---

## 8. Crear un perfil de juego nuevo

Estructura mínima en `games/<juego>/`:

```
games/<juego>/
├── manifest.rb     # lista ordenada de los .rb del perfil (sin .rb, sin prefijos)
├── constants.rb    # Game.define con config/button_labels/constantes
└── <lectores>.rb   # un archivo por pantalla/sistema custom
```

`manifest.rb` (formato `%w[]`, orden = orden de carga):

```ruby
%w[
  constants
  pausemenu
  quests
  logros
]
```

`constants.rb` declara el perfil y su configuración base:

```ruby
PokeAccess::Game.define("<juego>") do
  config(:some_option, true)
  button_labels({ :aux1 => "Correr" })
end
```

**Regístralo en `games/catalog.json`**, la fuente única del instalador y del launcher. Cada entrada tiene
`key` (la carpeta en `games/`), `display` (el nombre hablado), `titles` (títulos exactos que buscar en el
`mkxp.json`/`Game.ini`), `detect` (regex sobre "carpeta + exe", o `null`), `exes` (nombres de exe
distintivos; un `Game.exe` genérico no identifica) y `engine` (`"gen6"`, `"gamedata"` o `"any"`). La
detección es por capas: primero `titles`, luego `detect`, luego `exes`, y si nada encaja se pregunta al
jugador. Cuando hay varios candidatos gana el **match más largo**, no el primero.

**Convención de nombres de módulo:** un lector específico de un juego que pudiera colisionar con un
módulo del core debe llevar el prefijo del juego (p.ej. `ZBattleBag`, `ZCrafting`, `AnilMenus`,
`ZPokedex`), no un nombre genérico bajo `PokeAccess::`. Así el spec de acoplamiento (sección 2) no lo lee
como una reapertura del core.

**Engine del juego:** determina si es gen-6 (Ruby 1.8.7: `$Trainer`, `PokeBattle_Scene`, `PBSpecies`) o
de la era GameData (`$player`, `Battle::Scene`, `GameData`). Si es gen-6, **todo el código del perfil debe
pasar `check187.py`** (sin `&.`, sin `->`, sin `&:sym`, sin `round/ceil/floor(arg)`, etc. — ver
[08_RUBY_FUNDAMENTALS.md](08_RUBY_FUNDAMENTALS.md)). No hay que tocar el CI: deriva la lista de perfiles de
las carpetas de `games/` que tengan `manifest.rb`, así que tu perfil entra en el smoke-load en cuanto
existe.

---

## 9. Lectores de plugins del fork de Sky (skyflyer / DBK)

El fork "La Base de Sky" (Relict, Royal) trae plugins que no existen en Essentials vanilla, sobre todo el
**Deluxe Battle Kit (DBK)**. Sus lectores viven en `core/battle/skyflyer/` (compartidos por todos los
juegos del fork), no en un perfil de juego, porque el plugin es el mismo en todos.

La regla aquí es **gatear por existencia de MÉTODO** (no solo de clase): DBK reabre `Battle::Scene` y le
añade métodos (`pbUpdateBallSelection`, `pbUpdateBattlerInfo`, `pbToggleSpecialActions`...). La clase
`Battle::Scene` existe en cualquier juego de la era GameData, así que comprobar la clase no basta. Dos
formas equivalentes, según lo que necesites:

```ruby
# core/battle/skyflyer/dbk_selectors.rb -- selector de Poké Ball. :optional dice "este método falta
# legítimamente en juegos sin DBK": el hook no se ata y no genera un falso typo en Hooks.missing.
# pbUpdateBallSelection(items, index, showDesc) redibuja al abrir y en cada izq/der, y entrega el índice
# por args: es la excepción acotada al dedup con Cursor (la comparación es local al hook). El ivar vive en
# la Scene, que dura todo el combate, así que el abridor lo resetea.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbSelectBallInfo, :optional => true) do |scene, _a|
  scene.instance_variable_set(:@access_ball_idx, nil)
end
PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateBallSelection, :optional => true) do |scene, _ret, args|
  items = args[0]; index = args[1]
  if index != PokeAccess.ivar(scene, :@access_ball_idx)
    scene.instance_variable_set(:@access_ball_idx, index)
    t = PokeAccess::DBKSelectors.ball_text(items, index)
    PokeAccess.speak(t, true) if t && !t.to_s.empty?
  end
end

# Cuando además hay que decidir OTRA cosa según la capacidad (elegir método, montar constantes), el gate
# explícito es Engine.has?, que se activa en vanilla, en un fork que lo backportee o en una versión futura.
if PokeAccess::Engine.has?("Battle::Scene#pbUpdateBallSelection")
  # ...
end
```

Los selectores in-battle de DBK (qué Poké Ball lanzar, qué combatiente inspeccionar, las placas Arcy del
fork) son **cursores de sprite en la ruta crítica** (capturar, mecánica de tipos): exactamente el patrón
de la sección 3b, pero como van en `core/battle/skyflyer/` los comparte todo el fork. Lo específico de UN
juego del fork (p.ej. las placas Arcy, que solo están en Relict) sí va a su perfil
(`games/relict/plates.rb`).

> **No cruces versiones.** Un lector nunca debe llamar a otro de una versión distinta (eso significa que
> la lógica es agnóstica y debe subir a la raíz del módulo); el spec de acoplamiento lo bloquea. La lectura
> compartida de los menús de combate vive en `core/battle/scene_reader.rb` (`PokeAccess::BattleScene`)
> justamente por esto: las clases `Battle::Scene::*` son las mismas en v19-v22 vanilla, así que
> `battle/v21` y `battle/v22` solo aportan sus disparadores y ambos llaman a `BattleScene`. Ver
> [02_ARCHITECTURE.md](02_ARCHITECTURE.md).

---

## 9b. Lectores de plugins de terceros (`plugins/`)

Si la pantalla la trae un plugin que tienen **algunos** fangames y no todos, su lector no va ni al core ni
a un perfil: va a `plugins/`, y cada perfil que lo trae lo declara en su `manifest.rb`
(`:plugins => %w[...]`). Ver [02_ARCHITECTURE.md](02_ARCHITECTURE.md) para el porqué de la capa.

Antes de escribir una línea, **compara las dos copias del plugin en los volcados**. La trampa de esta capa
es que el mismo nombre de clase puede esconder dos plugins distintos, y el fallo resultante es mudo. Lo que
hay que comparar, en este orden:

1. Los **métodos que vas a enganchar**: que existan en las dos y con la **misma aridad**. Ya ha aparecido un
   `can_place_here?` con 4 parámetros en un fork y 3 en el otro.
2. Los **ivars que vas a leer**: mismo nombre y misma FORMA del dato. `@stock` guarda la receta entera en
   una copia y un id de `GameData` en otra; `@type_list[i]` parecía un id de tipo y era `["Planta", :GRASS,
   [iniciales]]`.
3. Los **métodos de apoyo** que vas a llamar (`obtener_archivo_captura`, `pbShowBattlePage?`): una copia
   puede no tenerlos. Ahí `respond_to?` sí y `rescue true` no — rescatar una ausencia a "sí" se inventa
   páginas o secciones que ese juego no tiene.
4. Que el método enganchado **no sea un `loop do` modal**: si lo es, un `after` habla una sola vez al
   cerrar y hace falta `SceneWatcher.reader`.

Lo que NO importa: el texto que el juego pinta (`ACTIVADO` / `ON`), colores y coordenadas. El lector saca el
estado del dato y lo dice por i18n, así que sale en el idioma del jugador en las dos copias.

Cuando las copias divergen de verdad, el lector **pregunta qué tiene la escena** en vez de asumir:

```ruby
# plugins/secret_bases.rb -- el fork añadió un cuarto argumento; llamar con la aridad equivocada revienta
# en cada frame y "cabe aquí" -- lo único que el jugador no puede saber de otra forma -- no se diría nunca.
def self.tile_ok?(scene, data, x, y, pos)
  m = (scene.method(:can_place_here?) rescue nil)
  return nil if m.nil?
  ((m.arity == 4) ? m.call(data, x, y, pos) : m.call(data, x, y)) ? true : false
end
```

Y la cabecera del fichero **deja escrito dónde divergen**: es el registro de la comprobación, y es lo que
permite revisarla dentro de un año sin repetirla entera.

Alta de un plugin, cuatro pasos:

1. `plugins/<nombre>.rb`, con la cabecera de divergencias y **todos los hooks `:optional`**.
2. Una línea en `plugins/manifest.rb`: `:<nombre> => "ClaseDelatora"` (la tabla de detección).
3. `:plugins => %w[... <nombre>]` en el manifiesto de cada perfil que lo trae.
4. Un spec que fije **la divergencia**, no lo obvio: si las dos formas no están en el test, el lector
   pasará verde el día que alguien simplifique la que no está cubierta.

---

## 10. Reglas que evitan los errores recurrentes

- **i18n siempre en el core.** Texto hablado nuevo = clave en `lang/es.txt` Y `lang/en.txt` (paridad
  exacta de claves, con test que la asegura). Excepción para perfiles monolingües: sección 0, punto 5.
- **Todo bajo `rescue`.** Un lector que peta no debe tumbar el frame. El patrón del repo es
  `(expr rescue valor_por_defecto)` y los helpers defensivos (`PokeAccess.ivar`, `PokeAccess.sprite`); el
  cuerpo de un hook además ya corre bajo `run_body`, que traga y loguea el primer fallo.
- **Dedup por instancia con `Cursor`**, nunca a nivel de módulo. Un ivar propio solo cuando el hook ya
  recibe por `args` el dato que compara (sección 3b).
- **Gate por clase/método.** Nunca asumas que una clase existe; `Game.define`/`Hooks` ya lo hacen por ti
  si pasas el nombre como string. Para un método que falta a propósito, `:optional => true`.
- **No reabras módulos del core desde un perfil**: usa `override` (secciones 2 y 5).
- **Verifica e instala.** `ruby test/run_all.rb` (specs de ambos motores + check187 + estáticos), luego
  sincroniza el install del juego (la causa nº1 de "no lee" es un install desfasado, no el código).

---

## 11. Diagnosticar una pantalla muda (Ctrl+Alt+F8 / Ctrl+Alt+F9)

Cuando un colaborador (o un usuario) reporta "esta pantalla no lee nada", este es el flujo, sin abrir el
`Scripts.rxdata` del juego:

1. **Ctrl+Alt+F8** activa/desactiva el mod entero (para confirmar rápido que el mod está cargado y que el
   problema es esa pantalla, no el arranque).
2. Entra en la pantalla muda y pulsa **Ctrl+Alt+F9**: anexa a `accessibility/data/diag.txt` (con fecha) el
   volcado completo — timings de `perf`, estado del motor y de la voz, salud de los enganches, y la
   sección `runtime introspection` del `$scene` actual.

La sección `runtime introspection` te da todo lo necesario para escribir el hook:

- `$scene=<clase>` con `methods=[...]` — los **candidatos a enganchar** (busca un `update`/`refresh`/
  `pbUpdate`/`selectButton`/`showTexts` que corra en cada movimiento del cursor).
- `ivars: [@index=3, @buttons=Array(8), ...]` — **dónde está el índice y dónde los datos**.
- `@sprites keys=[...]` con la clase e índice de cada ventana — para menús basados en `@sprites`.
- `live_selectables=[...]` — ventanas `Window_Selectable`/`Window_Command` vivas y visibles, incluso si
  no son `Window_DrawableCommand` (si la pantalla aparece aquí, casi seguro el core ya la lee y el
  problema es otro: un install desfasado, ver sección 10).
- `hooks: missing=[...] fn_absent=[...] overrides=[...]` — **la salud de tus enganches**: `missing` es
  probable typo (la clase existe, el método no), `fn_absent` es informativo (una función global que no
  está en ningún sitio) y `overrides` lista los reemplazos declarados y quién los puso.

**Lectura del diagnóstico (qué te dice cada caso):**

- ¿La pantalla **no** aparece como `live_selectables` ni como ventana de comando? → es un menú de sprite:
  engancha el método de selección y usa el patrón de la sección 3b. Si además bloquea en su propio bucle
  (nunca llega a ser `$scene`), es un caso de `SceneWatcher` (3c).
- ¿Aparece pero **lee mal** (id crudo, etiqueta vacía)? → `screen_reader` (sección 3a).
- ¿Tu clase sale en `missing`? → typo en el nombre del método, o el método falta de verdad y toca
  `:optional => true`.
- ¿`$scene` es una clase que **no esperabas** (nombre distinto al de otra versión)? → el juego renombró la
  clase; ata el hook al nombre real (el motor gatea por existencia, así que no rompe los demás).

Con eso escribes el hook sin extraer el fuente. Si aun así lo necesitas, los scripts compilados en
`Data/Scripts.rxdata` se vuelcan a texto con un cargador Marshal+Zlib (sin descompilar): se leen las
entradas `[magic, nombre, zlib]` y se infla cada una. El runtime introspection suele bastar para no llegar
a esto.
