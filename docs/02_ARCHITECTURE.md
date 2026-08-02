# Arquitectura de PokeEssentialsAccess

## Visión General

PokeEssentialsAccess utiliza un modelo de **capas escalonadas** donde cada capa depende de las anteriores y ofrece servicios a las posteriores. Esta estructura permite:

1. **Reutilización**: El core se usa en todos los juegos
2. **Mantenibilidad**: Cambios en Essentials se adaptan en una sola capa
3. **Testabilidad**: Cada capa puede probarse independientemente
4. **Extensibilidad**: Nuevos juegos solo necesitan su capa específica

## Capas de la Arquitectura

### Capa 1: Foundation y Util (Cimientos)

**Ubicación**: `core/foundation/`, `core/util/`

**Propósito**: Subsistemas universales que todos los módulos necesitan

| Archivo | Responsabilidad |
|---------|-----------------|
| `foundation/config.rb` | Definición de todas las opciones de usuario (`SCHEMA`) |
| `foundation/const.rb` | Introspección 1.8.7-safe: resolución de constantes "A::B::C" (`const_at`) e ivars/sprites de escenas (`ivar`/`ivar_i`/`sprite`) -- la primitiva que usan Hooks, Input, Menus y `Engine.has?` |
| `foundation/engine.rb` | Era del motor por API de datos (`gamedata?`/`gen6?`) y gate por capacidad (`has?`) |
| `foundation/events.rb` | Bus de eventos interno (`on`/`emit`) |
| `foundation/caches.rb` | Registro de estado por-run; `reset_all` en `:map_changed` (cargar partida pasa por `Locator.forget_map` -> `:map_changed`) |
| `foundation/game.rb` | DSL de perfiles: `Game.define("royal") { ... }` |
| `foundation/settings.rb` | Carga/guarda settings del usuario |
| `foundation/paths.rb` | Rutas en disco (DATA, SOUNDS, LIB, LANG); DATA cae a AppData si el juego es de solo lectura |
| `foundation/i18n.rb` | Traducciones multiidioma; `parity_issues` valida es/en |
| `foundation/clipboard.rb` | Acceso al portapapeles (Win32API) |
| `foundation/perf.rb` | Monitoreo de rendimiento |
| `foundation/tags.rb` | Etiquetas de usuario para objetos |
| `foundation/map_names.rb` | Nombres de mapa personalizados |
| `util/kv_file.rb` | El ÚNICO parser de los ficheros `clave=valor` del mod (lang, settings.ini, tags.txt, map_names.txt) |
| `util/grouping.rb`, `util/text.rb`, `util/player.rb` | Helpers puros: union-find, ensamblado de frases, datos del entrenador |
| `util/recorder.rb` | Grabador de sesiones (ver más abajo) |

**Ejemplo de dependencia**:
```
const.rb    depende de: nada (introspección pura, 1.8.7-safe)
kv_file.rb  depende de: nada (parser puro)
hooks.rb    depende de: const.rb (resolución de clase)
engine.rb   depende de: const.rb (has? resuelve constantes)
i18n.rb     depende de: paths.rb, kv_file.rb (lee las tablas de idioma)
caches.rb   depende de: events.rb (se engancha a :map_changed)
settings.rb depende de: config.rb (lee el schema), kv_file.rb
```

> **Regla de versiones**: una versión NUNCA depende de otra. El contenido agnóstico vive en la raíz del
> módulo (p.ej. `party/summary_gamedata.rb` = `SummaryGameData`, compartido por la escena clásica y v22);
> `party/gen6/summary_g6.rb` = `SummaryGen6` queda fuera del namespace agnóstico; las carpetas `vNN/` solo
> contienen DISPARADORES (qué clase enganchar), gateados por capacidad. Ver [03](03_ENGINE_DETECTION.md).
>
> La regla no es disciplina: la vigila `test/static/coupling_spec.rb`, que mapea cada módulo/clase/constante
> a la capa que lo DEFINE (`gen6`/`v21`/`v22`/`skyflyer`, core `:shared` o `games/<perfil>`) y falla ante
> cualquier referencia cruzada -- versión que usa otra versión, perfil que usa otro perfil, o `:shared` que
> usa una versión. Las excepciones conscientes viven en una whitelist del propio test, con su motivo.

### Capa 2: Data (Acceso a Datos)

**Ubicación**: `core/data/`

**Propósito**: Abstracción de datos entre versiones de Essentials

**Por qué es necesario**:
- **Gen-6**: `PBSpecies.getName(123)` → "Scyther"
- **Era GameData**: `GameData::Species.get(123).name` → "Scyther"

**Solución**: Provider pattern

```ruby
module PokeAccess::Data
  @providers = []

  # Cada provider se registra SOLO si sus constantes existen en este juego (el guard vive en el
  # propio data_g6/data_v21), así que "el activo" es sencillamente el de mayor prioridad registrado.
  def self.register(priority, provider)
    @providers.push([priority, provider]); @active_entry = nil
  end

  def self.active_entry
    @active_entry ||= @providers.max_by { |pr| pr[0] }   # memoizado; se invalida al registrar
  end

  def self.active; e = active_entry; e && e[1]; end
end
```

| Archivo | Prioridad | Responsabilidad |
|---------|-----------|-----------------|
| `data.rb` | — | Sistema de providers |
| `data_fallback.rb` | 0 | Devuelve IDs crudos como último recurso |
| `gen6/data_g6.rb` | 10 | Provider gen-6 (tablas `PB*`) |
| `v21/data_v21.rb` | 20 | Provider de la era GameData |

```ruby
PokeAccess::Data.species_name(123)  # → el provider activo
  └─ v21: GameData::Species.get(123).name │ gen6: PBSpecies.getName(123) │ nada: "123"
```

### Capa 3: Input & Speech (Entrada y Voz)

**Ubicación**: `core/input/`, `core/speech/`

**Propósito**: Interfaz con periféricos y síntesis de voz

**Componentes**:

| Módulo | Función |
|--------|---------|
| `speech/speech.rb` | Voz y braille vía `prism_pea.dll` → `prism.dll` (Win32API) |
| `speech/text.rb` | Normalización/limpieza de texto hablado |
| `speech/markers.rb` | Logging de diagnóstico |
| `input/hooks.rb` | Semi-API de patching: `before_hook`/`after_hook`/`around_hook`/`frame_hook`/`override`/`wrap_global`/`wrap_kernel` con guarda de reentrancia (ver [04](04_PATCHING_AND_HOOKS.md)) |
| `input/keyboard.rb` | `PokeAccess::Keyboard`: teclado físico puro (`raw_down?`, flancos `triggered?`/`combo_triggered?`, códigos VK). Sin conocimiento del mod |
| `input/focus.rb` | `PokeAccess::Focus`: foco de la ventana del juego (`focused?`, `mark_focused`, `hwnd`); fail-safe a "enfocado" |
| `input/remap.rb` | Remapeo de controles |
| `input/input.rb` | `PokeAccess::Keys`, el ORQUESTADOR: `enabled`/toggle, `global_poll`, `key(:sym)`, ventanas de supresión, pollers por frame. Delega en Keyboard y Focus |
| `input/diag.rb` | La mitad diagnóstica de `Keys` (reabre el módulo): Ctrl+Alt+F9/F10, las secciones del volcado, la introspección de runtime |

**La entrada está partida en tres a propósito**: lo que no es del mod (leer el hardware, leer el foco) vive
en módulos autónomos, copiables a otro proyecto y testeables sin arrancar el toolkit; lo que solo tiene
sentido para ESTE mod (si el mod está activo, qué nombre de tecla es qué VK, no comerse las teclas del
juego mientras el jugador escribe) vive en `Keys`, que llama a los otros dos.

**Ejemplo: Síntesis de voz**:
```ruby
# core/speech/speech.rb -- prism_pea.dll es el puente cdecl plano del mod sobre la API de prism.dll
# (fuente: bridge/prism_pea.c). prism maneja NVDA/JAWS/SAPI/UIA/ZDSR y más, en UTF-8 directo.
Win32API.new("prism_pea.dll", "PeaSpeak", ["p", "i"], "i")
  ├─ "p" = puntero a string (UTF-8, terminado en \0)
  ├─ "i" = entero (0=encolar, 1=interrumpir)
  └─ Returns: "i" (integer status)

PokeAccess.speak("Entrada a Pelota Roja", true)  # Lee con síntesis
PokeAccess.braille("Entrada a Pelota Roja")      # Misma línea a la pantalla braille
```

Ambas DLL se instalan por arquitectura en `accessibility/lib/`, que `SetDllDirectoryA` añade a la ruta de
búsqueda para que el puente encuentre su motor.

**Punto de extensión único**: `PokeAccess.on_speak = lambda { |text, interrupt| ... }` observa TODO lo que
se habla. Es lo que permite que el grabador de sesiones transcriba una partida sin un solo hook dentro de
los lectores; por defecto es nil (coste: un check por línea) y un observador que revienta se traga, porque
un instrumento jamás debe poder enmudecer el mod.

### Capa 4: Navigation & Audio 3D

**Ubicación**: `core/nav/`, `core/audio/`

**Propósito**: Sistemas de navegación y sonido posicional

| Archivo | Responsabilidad |
|---------|-----------------|
| `nav/locator.rb` | Encuentra y anuncia los eventos cercanos (NPCs, objetos, salidas) |
| `nav/locator_naming.rb` | Genera el nombre de un evento por la FORMA de su dato, no por su nombre |
| `nav/locator_surfaces.rb` | Identifica superficies (agua, hierba, árbol...) |
| `nav/pathfinder.rb` | Rutas con A*/JPS/HPA* y flood de alcanzabilidad |
| `nav/terrain.rb` | Clasifica terrenos (pasable, ledge, hielo...) |
| `nav/region_map.rb`, `nav/guide.rb` | Mapa regional y guía paso a paso |
| `audio/audio3d.rb` | Motor HRTF binaural (PA3D_steam.dll) |
| `audio/spatial.rb` | Mapeo de eventos a emitores de sonido |
| `audio/glossary.rb` | Catálogo de los sonidos NO verbales, para aprenderlos |

```ruby
# core/audio/audio3d.rb
INIT = Win32API.new("PA3D_steam.dll", "PA3D_Init", [], "i")
SET  = Win32API.new("PA3D_steam.dll", "PA3D_Set", ["i", "i", "i", "i", "i"], "v")
  ├─ Argumentos: [canal, x, y, VOLUMEN(0-100), on(1/0)]  (NO hay eje Z: es panorámica 2D por HRTF)
  └─ Posiciona y reproduce/silencia un canal de audio
```

**Glosario de sonidos**: la mitad de lo que el mod le dice al jugador no son palabras, sino SEÑALES (los
pings del sonar, el golpe contra la pared, los pasos, el bastón guía), y aprenderlas encontrándoselas en el
campo es lento y ambiguo. El menú de configuración recorre `SoundGlossary::ENTRIES`: al moverse dice el
nombre del sonido, la tecla de ayuda cuenta cuándo suena, y confirmar lo reproduce. Las previsualizaciones
son planas (centradas, volumen completo, canal SE normal) porque el objetivo es memorizar el TIMBRE. Los
ficheros son exactamente los que carga el motor de audio, así que el glosario no puede desincronizarse.

### Capa 5: Battle & Menus (Batalla y Menús)

**Ubicación**: `core/battle/`, `core/menus/`

**Propósito**: Accesibilidad de pantallas del juego

**Battle**:
```
core/battle/
├── battle.rb                ← Lógica compartida
├── move_info.rb             ← Formato compartido del detalle de un movimiento
├── scene_reader.rb          ← BattleScene: lectura AGNÓSTICA de los menús Battle::Scene::*
├── gen6/battle_g6.rb        ← Hooks para PokeBattle_Scene (autónomo)
├── v21/battle_v21.rb        ← Disparadores de v19-v21/Sky → BattleScene
├── v22/battle_v22.rb        ← Disparadores propios de v22 → BattleScene
└── skyflyer/                ← Deluxe Battle Kit
```

**Menus**:
```
core/menus/
├── menus.rb                 ← Framework universal (def_extractor, poll_sprite_menu, generic_focus)
├── cursor.rb                ← Primitiva de dedup de cursor (carga antes de menus)
├── scene_watcher.rb         ← Lectores por frame atados a una escena (SceneWatcher.reader/wire)
├── config_menu.rb           ← El menú de configuración del propio mod (+ glosario y depuración)
├── neo_pausemenu.rb         ← Lector del menú de pausa "Neo" (un plugin concreto), no el genérico
├── command_help.rb          ← Línea de ayuda de pbShowCommandsWithHelp / pbShowCommandsRogue
├── battle_point_shop.rb     ← Tienda de Puntos de Combate (extractor registrado globalmente)
├── sprite_button_menu.rb    ← Lector opt-in de menús de pausa de sprites (SpriteButtonMenu.define)
├── options.rb               ← Pantalla de opciones clásica (v22 va aparte en v22/options_v22.rb)
├── pokedex_entry.rb         ← Entrada de Pokédex
└── gen6/, v21/, v22/, skyflyer/  ← Disparadores por motor
```

> Los plugins de la comunidad que aparecen en muchos fangames pero no en todos tienen su lector en el core,
> descrito por el PLUGIN o el patrón que cubre, nunca por la lista de juegos que lo usan. Dos formas de
> engancharlo, según lo que haga falta: si basta con la clase (un extractor de ventana), se registra
> globalmente y sencillamente no se alcanza donde la clase no existe (`battle_point_shop.rb`); si el hook
> necesita saber a qué perfil pertenece, el perfil **se suscribe** con una línea
> (`SpriteButtonMenu.define(juego)`, `LocationBanner.define(juego)`).

### La capa `plugins/`: lectores de plugins de terceros

Un plugin que solo tienen ALGUNOS fangames no es core (el core es lo que trae cualquier Essentials) ni es
de un juego (el mismo plugin, con las mismas clases, sale en varios). Esos lectores viven en `plugins/`, y
cada perfil **declara** cuáles carga en su `manifest.rb`:

```ruby
{ :modules => %w[constants monotype], :plugins => %w[challenge_rules hall_of_fame_bw photo_album] }
```

Declarar en vez de autocargar es deliberado, y la razón es la trampa central de esta capa: **dos juegos
pueden traer el mismo plugin con el mismo nombre de clase y tripas distintas**. Casos reales ya vistos:

| Plugin | Coinciden | Divergen |
|---|---|---|
| Item Crafting | clase, métodos de redibujado | `@stock` guarda la receta EN LÍNEA en una copia y un id de `GameData::Recipe` en otra |
| Fotos del equipo | nombres de fichero, ivars del cursor | una resuelve el fichero por `obtener_archivo_captura`, la otra no tiene ese método |
| Secret Bases | ventanas de lista idénticas | `can_place_here?` tiene **4 parámetros en un fork y 3 en el otro** |
| BerryDex | ventana de lista idéntica byte a byte | una tiene 4 páginas de detalle y la otra 2, sin los predicados `pbShow*Page?` |
| Challenge Modes | clase idéntica en las 3 copias | solo cambia el texto PINTADO (`ACTIVADO` / `ON`), que el lector no usa |
| Incubadora | el fichero entero, byte a byte | nada |

Por eso un lector de `plugins/` **pregunta qué tiene la escena** (`respond_to?`, aridad del método, forma
del dato) en vez de asumir una, y la cabecera de cada fichero deja escrito dónde divergen las copias: ese
comentario es el registro de la comprobación. Reglas de la capa, ambas con test estático
(`test/static/plugins_spec.rb`):

1. Un plugin declarado tiene que EXISTIR: si no, ese juego pierde la pantalla en silencio.
2. Todo hook de `plugins/` es `:optional`, para que `Hooks.missing` siga significando "typo" y no se llene
   de ausencias esperadas.

`plugins/manifest.rb` es además una **tabla de detección** (`nombre => clase delatora`) que se lee siempre,
aunque no se cargue ningún lector: el diagnóstico puede así avisar de "este juego trae un plugin que
conocemos y tu perfil no lo declaró", que es justo el único fallo del declarado-a-mano.

> Nota de convención: el layout es **módulo-primero**. Cada subsistema (`battle/`,
> `menus/`, `party/`...) tiene sus lectores agnósticos en la raíz y subcarpetas `gen6/`, `v21/`, `v22/`,
> `skyflyer/` solo para lo que difiere por versión, cada una gateada por existencia de clase. La lógica
> COMPARTIDA por varias versiones va a la RAÍZ del módulo, no a una subcarpeta de versión: p.ej. el lector
> de los menús de combate vive en `core/battle/scene_reader.rb` (`PokeAccess::BattleScene`) porque las
> clases `Battle::Scene::*` son las mismas en v19-v22 vanilla; `battle_v21.rb` y `battle_v22.rb` solo
> enganchan los disparadores propios de su versión (cómo abre/navega cada una) y delegan el contenido en
> `BattleScene`. En gen-6 ese módulo se carga pero no se alcanza (sus disparadores no existen).

**Cómo funciona el hooking** (detalle en [04](04_PATCHING_AND_HOOKS.md)):
```ruby
# El juego pinta el mensaje en PokeBattle_Scene#pbDisplayMessage; el mod lo habla antes,
# sin tocar el método original (en gen6/battle_g6.rb):
PokeAccess::Hooks.before_hook("PokeBattle_Scene", :pbDisplayMessage) do |scene, args|
  PokeAccess.speak_clean(args[0], false)
end
```

### Capa 6: Field (Campo)

**Ubicación**: `core/field/`

**Responsabilidad**: Interacción con el mapa y eventos

**Componentes**:

| Archivo | Función |
|---------|---------|
| `contextual.rb` | Lectura de contexto del jugador |
| `hud_text.rb` | Texto que el juego pinta en pantalla fuera de una ventana (`Kernel.pbDisplayText`) |
| `minigames.rb` | Minijuegos estándar (p.ej. Voltorb Flip) |
| `minigame_text.rb` | Texto/navegación de minijuegos con ventana propia (p.ej. Triple Triad) |
| `fishing.rb`, `berry.rb`, `incubator.rb` | Pesca, bayas, incubadora de huevos |
| `achievements.rb`, `hall_of_fame.rb`, `quests.rb` | Logros/medallas, salón de la fama, misiones |
| `mail.rb`, `phone.rb`, `book.rb`, `tip_cards.rb`, `itemfinder.rb` | Correo, teléfono, libros, tarjetas de consejo, buscaobjetos |
| `location_banner.rb` | Lector opt-in de carteles de zona (`LocationBanner.define`) |
| `../puzzles/puzzles.rb` | Ayuda con puzles (subsistema propio `core/puzzles/`, no `field/`) |
| `v21/` | Disparadores específicos v21 |

### Capa 7: Juego Específico

**Ubicación**: `games/<nombre>/`

**Propósito**: Personalizaciones y lectores de las pantallas que solo tiene ese juego

```ruby
# games/royal/manifest.rb -- misma mecánica que el manifest del core: lista ordenada, sin .rb
%w[
  constants       # PokeAccess::Game.define("royal") { ... }: config, hooks, secciones de diag
  selectors       # lectores de las pantallas propias del juego
  curry_select
  hall_viewer
]
```

`Game.define` es el DSL del perfil: `config`, `screen_reader`, `before`/`after`/`around`/`read_on_open`,
`override`, `kernel`, `diag_section`, `poll_each_frame`, `puzzle`, `hazard`, `remap_extra`... Un perfil
DECLARA; no redefine módulos del core reabriéndolos (lo caza el test de acoplamiento, con `Config` como
única excepción, y solo para asignarle constantes de ajuste). Para reemplazar comportamiento del core está
`Hooks.override`, que además queda listado en el diag.

### Juegos soportados

Cada juego soportado tiene su perfil en `games/<perfil>/` y un motor de Essentials. El perfil añade los
lectores de sus pantallas custom; el core cubre todo lo común a ese motor. La fuente única de la lista es
`games/catalog.json`, que consumen el instalador y el launcher (y de la que come el test
`test/static/catalog_detect_spec.rb`); al dar soporte a un juego nuevo se añade allí, en esta tabla y al CI.

| Juego | Perfil | Motor |
|-------|--------|-------|
| Pokémon Z | `pokemon_z` | gen-6 (Ruby 1.8.7) |
| Pokémon Ópalo | `opalo` | gen-6 |
| Pokémon Reminiscencia | `reminiscencia` | gen-6 |
| Pokémon Armonía | `armonia` | gen-6 |
| Pokémon Realidea | `realidea` | gen-6 |
| Pokémon Africanus | `africanus` | gen-6 |
| Pokémon Awakening | `awakening` | gen-6 |
| Pokémon Añil | `anil` | era GameData (v21.1, Ruby 3.x) |
| Pokémon Royal | `royal` | era GameData (La Base de Sky: DBK/LBDS/MUI) |
| Pokémon Relict | `relict` | era GameData (Essentials moderno + MUI + ArcyGame) |
| Pokémon Infinite Fusion | `infinitefusion` | era GameData (v18: `GameData` con `$Trainer`) |
| Pokémon Infinite Fusion 2 Hoenn | `infinitefusion_hoenn` | era GameData (v18) |
| (cualquier fangame sin perfil) | `generic` | solo los lectores del core |

El motor decide la API que usan los lectores: gen-6 (`$Trainer`, `PokeBattle_Scene`, `PB*`) frente a la era
GameData (`$player`, `Battle::Scene`, `GameData`); v22 añade el rework `UI::*` y el fork de Sky, los
plugins del Deluxe Battle Kit. Ver [03_ENGINE_DETECTION.md](03_ENGINE_DETECTION.md).

## Flujo de Ejecución

### Inicio

```
1. mkxp-z lee mkxp.json y ejecuta el preloadScript (loader/preload_access.rb)
2. El preload envuelve Graphics.update y espera: las clases del juego aún no existen
3. Cuando el bucle principal ya corre ($scene definido, o 120 frames de red de seguridad),
   evalúa boot.rb UNA vez
4. PokeAccessBoot.run: core/ por manifest → game/<perfil>/ por manifest → settings del usuario
```
Detalle completo en [09_LOADING_SYSTEM.md](09_LOADING_SYSTEM.md).

### Durante el Juego

```
Cada frame (el hook de Input#update):
├─ PokeAccess::Remap.update → Traduce los controles remapeados
├─ PokeAccess::Keys.global_poll → Ctrl+Alt+F8/F9/F10 y las hotkeys contextuales del jugador
├─ PokeAccess::Keys.run_frame_pollers → Corre los pollers registrados (poll_each_frame)
└─ El juego original continúa normalmente

Cada frame (frame_hook sobre Game_Player#update, solo en el campo):
├─ Locator.map_poll → Reconstruye destinos, anuncia lo que cambió
├─ Audio3D → Reposiciona emitores y paredes
└─ Recorder.sample → Solo si hay una grabación en curso

En cualquier momento (hooks sobre métodos de Essentials):
└─ Se llama un método del juego → el hook lee el contexto y habla
```

### Ejemplo Completo: Navegar a un NPC

```
Jugador pulsa la tecla de coordenadas/localizador (configurable, ver Config.keys)
  ├─ Keys.global_poll la detecta (clase real: PokeAccess::Keys, no ::Input)
  ├─ Locator escanea los eventos cercanos
  │  ├─ Data → nombres de especie/objeto      └─ Tags → etiquetas del jugador
  ├─ Habla el destino con PokeAccess.speak() → prism_pea.dll → prism.dll
  └─ Pathfinder.find_path() → A* esquivando obstáculos → lista de tiles [x, y]
```

## Modelo de Datos

### Config Schema

```ruby
PokeAccess::Config::SCHEMA = [
  #  key                  default  kind   group        label            help
  [:language,            :es,     :lang, :general,    :lbl_language,   :help_language],
  [:auto_guide,          false,   :flag, :pathfinder, :lbl_auto_guide, :help_auto_guide],
  [:audio3d_volume,      80,      :vol,  :audio,      :lbl_pos_master, :help_pos_master],
]
```

Una fila = una opción de usuario. `Settings` y `ConfigMenu` derivan los dos del schema, así que añadir una
opción es añadir una fila; los `kind` numéricos toman su rango de `KIND_BOUNDS`.

### Tags de Usuario

```
# accessibility/data/tags.txt
123:456=Mi Arbol Magico	cat=objects
124:1=Puerta	hide
125:10=Estatua	cat=signs

Formato:
<map_id>:<event_id>=<nombre_personalizado>	[cat=<people|objects|exits|signs>] [hide]
```

Es un fichero `clave=valor` como el resto (idioma, `settings.ini`, `map_names.txt`), todos leídos por el
mismo parser: `PokeAccess::KVFile`.

## Patrones de Diseño Utilizados

| Patrón | Dónde | Qué resuelve |
|--------|-------|--------------|
| **Provider** | `Data` | Varias implementaciones de la misma API de datos, sin condicionales en el que llama |
| **Hook/Observer** | `Hooks`, `Events` | Reaccionar a métodos y a cambios sin tocar las clases del juego |
| **Factory/DSL** | `Game.define` | Un perfil de juego se declara, no se programa |
| **Capability Gating** | `Engine.has?` | Los lectores se atan por CAPACIDAD (clase/método presente), nunca por número de versión, así que un fork o una versión futura que conserve la feature funciona sin cambios. La carpeta `vNN/` solo marca dónde se introdujo |
| **Cursor Dedup** | `core/menus/cursor.rb` | "Habla solo cuando el cursor cambia" en UNA primitiva (`changed?`/`announce`/`reset`), en vez de un ivar `@access_*` por lector |
| **Observador de voz** | `PokeAccess.on_speak` | El único punto de extensión sobre lo hablado; el grabador se cuelga de ahí y no de los lectores |

## Diagnóstico y Grabación

Dos instrumentos, y ninguno de los dos vive dentro de los lectores:

| Gesto | Qué hace |
|-------|----------|
| Ctrl+Alt+F8 | Activa/desactiva el mod entero (y reintenta el arranque de la voz) |
| Ctrl+Alt+F9 | Genera/anexa `accessibility/data/diag.txt`: motor y capacidades, voz, timings en ms, mapa/localizador/pathfinder, y una introspección de runtime (clase del `$scene`, sus métodos e ivars) para pantallas mudas |
| Ctrl+Alt+F10 | HABLA un diag corto: escena / mapa+posición / última lectura / hooks ausentes |
| Menú de config → Depuración | Copia al portapapeles un subconjunto del diag, y arranca/para el grabador |

```
perf: map_poll=0.5ms audio3d=1.2ms pathfinder=2.1ms
```

**Secciones de diagnóstico por perfil**: el core es agnóstico del juego, así que un fangame con mecánicas
propias las diagnostica él mismo. `Keys.register_diag_section(nombre, grupo) { |o| o.push("...") }`
(expuesto a los perfiles como `diag_section` en `Game.define`) añade una sección al volcado completo y al
grupo del menú de depuración, guardada igual que las nativas: una sección de perfil que revienta no se
lleva por delante el resto del volcado.

**Grabador de sesiones** (`core/util/recorder.rb`): convierte una partida real en una TRANSCRIPCIÓN de lo
que el mod vio y lo que dijo, en orden. Sirve para dos cosas con un solo fichero: un tester que oye
enmudecer el mod entrega una grabación en vez de intentar describir el momento, y `test/support/replay.rb`
audita ese mismo fichero buscando los tres fallos que importan (un cursor que se movió sin hablar, la misma
línea dos veces seguidas, un lector que dijo códigos de control). No engancha NADA dentro de los lectores:
todo lo que sabe le llega por `PokeAccess.on_speak` y por una lectura por frame de estado que el mod ya
mantiene, así que el instrumento nunca puede romper un lector. Apagado cuesta un check nil por línea.

## Rendimiento

| Optimización | Cómo |
|--------------|------|
| Caché de pasabilidad | `route_cache` memoiza el costoso `passable?` del motor entre la flood, A* y la guía |
| Flood solo si hace falta | La reachability flood solo corre para destinos lejanos; los cercanos los resuelve A* directo |
| Carga perezosa | Audio3D solo inicializa si la DLL está disponible |
| Limpieza por mapa | `Caches.reset_all` en `:map_changed` tira el estado por-run de todos los registrantes a la vez |
| Medición | `Perf.measure(:etiqueta) { ... }` alimenta la línea `perf:` del diag, que se resetea en cada captura |

## Siguientes Pasos

- [Engine Detection](03_ENGINE_DETECTION.md) - Cómo detecta versiones
- [Patching & Hooks](04_PATCHING_AND_HOOKS.md) - Sistema de hooks
- [Data API](05_DATA_API.md) - Cómo funciona acceso a datos
- [Extending](14_EXTENDING.md) - Cómo añadir hooks, lectores, puzzles y perfiles
