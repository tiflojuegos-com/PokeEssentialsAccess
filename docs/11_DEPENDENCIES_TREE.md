# Árbol de Dependencias

Visualización de cómo los módulos dependen unos de otros.

## Diagrama General

```
mkxp-z (C++/Ruby Runtime)
    ↓
Graphics.update [envuelto en preload_access.rb]
    ↓
AccessPreload (loader/preload_access.rb)
    │ Espera: ¿$scene definido? o ¿READY_FRAME (120) frames?
    ↓
PokeAccessBoot.run (loader/boot.rb)
    ├─ load_manifest("accessibility/core")
    ├─ load_manifest("accessibility/game")
    ├─ PokeAccess::Settings.apply
    └─ Diagnósticos (hooks sin método, Data en emergencia, i18n sin paridad)
    ↓
PokeAccess Fully Loaded
```

## Jerarquía de Carga: CORE

El orden real y COMPLETO de carga vive en `core/manifest.rb` (un array `%w[...]` de entradas
`subsistema/nombre`, sin `.rb`, evaluado por `loader/boot.rb` en ese orden exacto). El árbol de abajo es un
extracto ilustrativo con los módulos fundacionales y una muestra de cada subsistema; hay muchos más
(menús, battle por versión, party, field, nav) que el manifest carga después. Para saber qué se carga y en
qué orden, consulta siempre el manifest, no este extracto.

```
core/manifest.rb (extracto del orden de carga)
├── foundation/config
│   └─ SCHEMA = [[:language, :es, ...], ...]  |  KIND_BOUNDS = {:vol => [0, 100, ...], ...}
│
├── foundation/const
│   └─ PokeAccess.const_at("A::B::C") - resolución de constantes 1.8.7-safe
│      + ivar / ivar_i / sprite - introspección defensiva de objetos del motor
│      ↑ CRITICO: lo usan Hooks, Input, Menus, Engine.has? (carga pronto, sin dependencias)
│
├── foundation/paths
│   └─ ROOT / CORE / GAME / SOUNDS / LIB / LANG y DATA (que cae a AppData si el juego es de solo lectura)
│
├── util/kv_file
│   └─ KVFile.each(path, :strip_value => ...) - el ÚNICO parser clave=valor del mod
│      ↑ Lo usan i18n, settings, tags y map_names (antes eran cuatro copias a mano)
│
├── foundation/i18n
│   └─ Carga lang/en.txt, lang/es.txt; I18n.parity_issues valida es/en
│      Depende de: Paths, KVFile
│
├── util/grouping
│   └─ Util.union_groups(n) { |i,j| ... } - agrupa por union-find (emisores/salidas cercanas)
│
├── util/text
│   └─ Util.join_parts(partes), Util.types_phrase(t1, t2) - ensamblado de líneas habladas
│
├── util/player
│   └─ Util.playtime_parts(secs), Util.badge_count(who) - helpers de datos del entrenador
│
├── foundation/game
│   └─ El DSL de perfiles: PokeAccess::Game.define("royal") { ... }
│      Delega en Config, Menus, Hooks, Keys, Remap, Puzzles, Locator (en tiempo de llamada)
│
├── foundation/engine
│   ├─ Engine.has?(cap) - EL gate por capacidad (símbolo registrado / "Clase" / "Clase#metodo")
│   ├─ Engine.player - $player (era GameData) o $Trainer (gen-6)
│   ├─ Engine.kind / version / fork - solo para el diagnóstico y la cabecera del grabador
│   └─ Depende de: const_at (has? resuelve constantes)
│      ↑ CRITICO: has? lo usa casi todo lector
│
├── foundation/settings
│   └─ Carga/guarda config del usuario   Depende de: Config (schema), KVFile
│
├── foundation/events
│   └─ Bus de eventos (on / emit)
│
├── foundation/caches
│   └─ Caches.register(:x) { reset } / reset_all - se dispara en :map_changed (depende de events)
│
├── foundation/clipboard
│   └─ Acceso a portapapeles (Win32API)
│
├── foundation/perf
│   └─ Perf.measure(:etiqueta) { ... } / report / reset - alimenta la línea perf: del diag
│
├── foundation/tags
│   └─ Etiquetas de usuario para eventos ("mapid:eventid=nombre" + cat=/hide)
│      Depende de: Paths, KVFile
│
├── foundation/map_names
│   └─ Nombres de mapa personalizados (Locator.rename_map); persiste en map_names.txt
│      Depende de: Paths, KVFile
│
├── data/data
│   ├─ Provider pattern: register(priority, provider), active, active_priority, resolve(metodo, arg)
│   └─ + la fachada de consulta (species_name, move_power, item_description...)
│      ↑ BASE: usado por data_fallback, gen6, v21
│
├── data/data_fallback
│   └─ Provider fallback (priority 0)   Depende de: data/data
│
├── data/gen6/data_g6
│   ├─ module PokeAccess::DataG6 - accede a PBSpecies, PBMoves, PBTypes, PBItems...
│   └─ Registra priority 10, solo si existen las constantes (PBMoves && !GameData)
│
├── data/v21/data_v21
│   ├─ module PokeAccess::DataV21 - accede a GameData::Species, GameData::Move...
│   └─ Registra priority 20, solo si existen las clases (GameData::Move)
│
├── speech/markers
│   └─ write_marker(), log_once(), DLL_DIR   Depende de: Paths (escribe a archivo)
│
├── speech/text
│   └─ clean() - quita los códigos de control de RPG Maker (\PN, \V[n], \C[n]...)
│
├── speech/speech
│   ├─ speak / speak_clean / braille / stop_speech / speaking? / speech_backend
│   ├─ on_speak= - el ÚNICO punto de extensión sobre lo hablado (lo usa el grabador)
│   ├─ Accede a: prism_pea.dll → prism.dll (Win32API), desde accessibility/lib/
│   └─ Depende de: markers (DLL_DIR, write_marker)
│
├── input/hooks
│   ├─ Semi-API: before_hook / after_hook / around_hook / frame_hook / read_on_open / override /
│   │  wrap_global / wrap_kernel; y los registros de salud missing / fn_absent / overrides
│   ├─ Guarda de reentrancia (@active, nested_other?, guarded); container/frame corren sin guarda
│   └─ Depende de: const_at (resolución de clase). Base de todo lector
│
├── input/keyboard
│   ├─ PokeAccess::Keyboard: raw_down?, all_down?, triggered? / combo_triggered? (flancos), edge?
│   ├─ Constantes VK de los acordes globales (CONTROL, ALT, F8, F9, F10)
│   ├─ Accede a: GetAsyncKeyState (Win32API)
│   └─ Depende de: nada (sin conocimiento del mod: copiable a otro proyecto)
│
├── input/focus
│   ├─ PokeAccess::Focus: focused?, mark_focused, hwnd. Fail-safe: si no se puede leer, "enfocado"
│   ├─ Accede a: GetForegroundWindow / GetActiveWindow / GetCurrentProcessId (Win32API)
│   └─ Depende de: nada (sin conocimiento del mod)
│
├── input/remap
│   └─ Remapeo de controles   Depende de: Config (lee rebinds)
│
├── input/input
│   ├─ PokeAccess::Keys, el orquestador: enabled/toggle_poll, global_poll, key(:sym), typing!/menu_lock!,
│   │  on_frame / run_frame_pollers. Engancha ::Input#update (el latido de cada frame)
│   └─ Depende de: Keyboard, Focus, Config, I18n, Speech, ConfigMenu, Info, Battle, Locator, Puzzles
│
├── input/diag
│   ├─ Reabre Keys con su mitad diagnóstica: Ctrl+Alt+F9 (volcado) y F10 (diag hablado)
│   ├─ DIAG_ALL / DIAG_SECTIONS, diag_build(secciones), register_diag_section(nombre, grupo)
│   └─ Depende de: Keys, Engine, Speech, Hooks, Perf, Clipboard, Locator, Pathfinder, Audio3D
│
├── menus/config_menu
│   └─ El menú del propio mod: ajustes, glosario de sonidos, etiquetas, remapeo, depuración
│      Depende de: Config, I18n, Speech, SoundGlossary, Tags, Recorder, Keys (diag)
│
├── nav/terrain
│   └─ label(x, y), ledge_at?, surfable_at?, ice?...   Depende de: terrain tags de Essentials
│
├── audio/spatial
│   └─ Mapeo de eventos a emitores de sonido; cue() para reproducir una muestra suelta
│      Depende de: Locator (obtiene eventos), Audio3D
│
├── audio/glossary
│   ├─ SoundGlossary::ENTRIES: [id, fichero, clave del nombre, clave de ayuda, tono] por señal
│   ├─ play(entry) - previsualización plana (centrada, volumen completo) para memorizar el timbre
│   └─ Depende de: Spatial.cue. Lo consume el menú de configuración
│
├── audio/audio3d
│   ├─ Motor HRTF binaural (Steam Audio) vía PA3D_steam.dll (Win32API)
│   ├─ Canales: npc, object, door, teleporter, hazard, wall, interact, control, trap, push,
│   │            water, wind_*, step, grass, fstep_water, guide
│   └─ Depende de: Paths (busca .wav), Config (volúmenes)
│
├── field/contextual
│   └─ Información contextual del jugador   Depende de: Engine, Data, Terrain
│
├── field/hud_text
│   └─ Texto que el juego pinta fuera de una ventana (Kernel.pbDisplayText)   Depende de: Hooks
│
├── puzzles/puzzles            (subsistema propio, no field/)
│   └─ Ayuda con puzles   Depende de: Config (puzzle_assist)
│
├── menus/cursor
│   └─ Cursor.changed? / on_change / announce / reset - primitiva de dedup por defecto (antes de menus)
│
├── menus/menus
│   └─ Framework: def_extractor, poll_sprite_menu (delega en Cursor), generic_focus
│      Depende de: Hooks, Speech, I18n, Config, Cursor
│      (el hook genérico de Window_Selectable/Command vive en input/input, no aquí)
│
├── menus/scene_watcher
│   └─ SceneWatcher.wire / reader - lectores por frame atados a una escena concreta
│
├── battle/battle
│   └─ Lógica compartida: describe_battle, announce_hp, announce_field...
│      Depende de: Data, Engine, I18n, Speech, Info
│
├── battle/move_info
│   ├─ MoveInfo: formato compartido del detalle de un movimiento (poder/precisión/PP/descripción)
│   └─ Lo usan todos los lectores de movimientos (combate, relearner/egg-move, página de movs del summary)
│
├── battle/scene_reader
│   ├─ BattleScene: lectura AGNÓSTICA de los menús Battle::Scene::* (comunes a v19-v22 vanilla)
│   ├─ read_menu / command_label / target_label / move_text / hp_change_text / ability_text
│   ├─ Solo DEFINE métodos (no engancha nada); lo invocan los hooks de v21/v22
│   └─ Depende de: Battle, MoveInfo, Data, I18n, Speech, Info
│
├── battle/gen6/battle_g6
│   ├─ Hooks específicos gen-6 (autónomo, no usa BattleScene): PokeBattle_Scene, CommandMenuDisplay,
│   │  FightMenuDisplay. Cada hook se ata solo si la clase/método existe
│   └─ Depende de: Hooks, battle/battle
│
├── battle/v21/battle_v21
│   ├─ Solo los disparadores de v19-v21/Sky (index=, setIndexAndMode, mode=, shiftMode=, hp, mensajes)
│   └─ Depende de: Hooks, battle/battle, battle/scene_reader
│
├── battle/v22/battle_v22
│   ├─ Solo los disparadores propios de v22 (set_index_and_commands, update_input, mega_evolution_state=)
│   └─ Depende de: Hooks, battle/battle, battle/scene_reader
│
├── battle/skyflyer/* (fork de Sky / DBK)
│   ├─ dbk_battle, dbk_moveinfo, dbk_battlerinfo, dbk_selectors (Poké Ball + selección de combatiente)
│   └─ Depende de: Hooks, battle/scene_reader. Cada hook gateado por existencia de método
│
├── nav/locator_naming
│   ├─ target_name: etiqueta de usuario, Pokémon salvaje, peligro, movimiento de campo, PALANCA
│   │  (toggle de 2 estados), salida, cartel, objeto. Detecta por la FORMA del dato del evento
│   └─ Depende de: Tags, Data, I18n
│
├── nav/locator / nav/guide / nav/pathfinder
│   └─ Ver "Sistema de Pathfinding" abajo
│
└── util/recorder            (el ÚLTIMO del manifest)
    ├─ Transcribe una sesión: say / map / pos / scene / sel / diag, con volcados de secciones del diag
    ├─ Se cuelga de PokeAccess.on_speak y de un frame_hook sobre Game_Player#update: CERO hooks dentro
    │  de los lectores, así que el instrumento no puede romper lo que mide
    └─ Depende de: Paths, Engine, Keys.diag_build, Locator, Spatial. Lo arranca el menú de depuración

(más módulos específicos...)
```

## Jerarquía de Carga: GAME

```
games/<nombre>/manifest.rb
├── constants
│   └─ PokeAccess::Game.define("royal") { ... }
│      config / screen_reader / before / after / around / read_on_open / override / kernel /
│      diag_section / poll_each_frame / puzzle / hazard / remap_extra / picture_texts
│
├── Módulos específicos del juego (lectores de sus pantallas propias)
│
└─ Depende de: core/ (completamente cargado)
```

## Árbol de Dependencias por Sistema

### Sistema de Datos (Data)

```
data/data
├─ Exporta: PokeAccess::Data (register, active, active_priority, resolve + la fachada de consulta)
└─ Usado por: casi todo

data/data_fallback (priority 0)   ← último recurso, siempre registrado
data/gen6/data_g6  (priority 10)  ← PBSpecies, PBMoves...   si PBMoves && !GameData
data/v21/data_v21  (priority 20)  ← GameData::Species...    si GameData::Move

El activo es sencillamente el de mayor prioridad REGISTRADO (el guard vive en cada provider),
memoizado y reinvalidado al registrar.

Usuarios de Data: battle/*, menus/*, field/contextual, party/summary, nav/locator_naming...
```

### Sistema de Audio 3D

```
audio/spatial
├─ Escanea eventos cercanos y los convierte en emitores
└─ Depende de: Locator (targets), Audio3D

audio/glossary
├─ El catálogo browsable de esas mismas señales
└─ Depende de: Spatial.cue

audio/audio3d
├─ Motor HRTF (Steam Audio), canales por categoría
└─ Depende de: Paths (.wav), Config (volúmenes) y accessibility/lib/PA3D_steam.dll + phonon.dll
   (que el instalador copia desde assets/<arch>/ según la arquitectura del ejecutable)
```

### Sistema de Pathfinding

```
nav/terrain          → label(x, y) y los predicados de terreno
nav/pathfinder       → A* / JPS / HPA* + flood de alcanzabilidad; depende de passable? de Essentials
nav/locator_surfaces → superficies (agua, hierba...); depende de Terrain.label
nav/locator_naming   → nombres de evento; depende de Tags, Data, I18n
nav/locator          → el centro: combina eventos, superficies y salidas
                       depende de pathfinder, locator_naming, locator_surfaces
nav/guide            → guía paso a paso sobre la ruta calculada
                       ↑ Usuario final: Keys (cuando el jugador pulsa la tecla del localizador)
```

### Sistema de Battle

```
battle/battle        (compartido)   announce_hp, announce_field...     ← Data, I18n, Speech
battle/move_info     (compartido)   detalle de un movimiento
battle/scene_reader  (agnóstico)    lee los menús Battle::Scene::*     ← battle, move_info, Data
battle/gen6/*        (gen-6)        hooks a PokeBattle_Scene, autónomo ← Hooks, battle
battle/v21/*         (v19-v21/Sky)  solo disparadores → BattleScene    ← Hooks, scene_reader
battle/v22/*         (v22)          solo disparadores → BattleScene    ← Hooks, scene_reader
battle/skyflyer/*    (Sky/DBK)      ball + selección de combatiente    ← Hooks, scene_reader

Integración:
├─ Gen-6: solo battle_g6 engancha
├─ v19-v22 vanilla: comparten las clases Battle::Scene::*, así que scene_reader lleva la LECTURA
│  y cada battle_vNN solo ata los métodos de apertura/navegación propios de su versión
└─ Sky: battle_v21 + battle/skyflyer/*
```

### Sistema de Menús

```
menus/cursor          → la primitiva de dedup; carga antes que todo lector de menú
menus/menus           → framework (def_extractor, poll_sprite_menu, generic_focus)  ← Hooks, Speech, Cursor
menus/scene_watcher   → SceneWatcher.reader/wire: lector por frame atado a una escena
menus/config_menu     → el menú del propio mod                                      ← Config, I18n, Speech
menus/v21/pausemenu_v21 → PokemonPauseMenu_Scene#pbShowCommands, atado con SceneWatcher.reader
                          ← scene_watcher, menus (generic_focus)
menus/v22/screen_v22    → V22.on_nav(clase, metodo) { |vis| ... }: el helper con el que se atan
                          los lectores del rework UI::                              ← Engine.has?, Hooks
menus/v22/pausemenu_v22 → UI::PauseMenuVisuals, gateado por Engine.has?             ← Hooks, Speech
```

## Importancia Relativa

| Nivel | Módulos |
|-------|---------|
| **CRÍTICO** (sin esto no funciona nada) | `foundation/const`, `foundation/config`, `foundation/paths`, `foundation/engine`, `data/data`, `speech/speech`, `input/hooks` |
| **MUY IMPORTANTE** | `input/input`, `menus/menus`, `menus/cursor`, `battle/battle`, `nav/locator`, `nav/pathfinder`, `audio/audio3d` |
| **IMPORTANTE** | `foundation/events`, `foundation/i18n`, `input/keyboard`, `input/focus`, `input/diag`, `audio/spatial`, `field/*` |
| **OPCIONAL** | `audio/glossary`, `util/recorder`, `field/achievements`, `puzzles/puzzles`, `field/fishing` |

## Dependencias Cruzadas

**No hay dependencias circulares**: el manifest está ordenado para evitarlas. Sí hay referencias hacia
adelante, y son legítimas, porque todo se carga antes de que el jugador toque nada:

```
Si X usa Y:
├─ Y DEBE estar en el manifest ANTES de X, si X lo usa AL CARGARSE (constantes, hooks que se atan ya)
└─ O basta con que Y exista cuando X se EJECUTE (dentro de un bloque de hook, en un poller...)
```

```ruby
# ✅ Válido: el cuerpo del hook se ejecuta más tarde, con todo cargado (nav/locator.rb)
PokeAccess::Hooks.frame_hook("Game_Player", :update) do |_p, _a|
  PokeAccess::Perf.measure(:map_poll) { PokeAccess::Locator.map_poll }
end

# ❌ Inválido: se evalúa AL CARGAR, y Menus todavía no existe desde speech/
PokeAccess::Menus.def_extractor("Foo") { ... }   # dentro de speech/speech.rb
```

## Cómo se Vigila el Orden

Dos tests estáticos, sin motor ni stubs, convierten estas reglas en CI:

| Test | Qué garantiza |
|------|---------------|
| `test/static/manifest_check.rb` | Todo `.rb` de `core/` y de cada `games/<perfil>/` está listado exactamente una vez, y toda entrada listada tiene fichero. Caza el lector nuevo sin registrar y la entrada renombrada |
| `test/static/coupling_spec.rb` | Ninguna referencia cruzada entre capas: una versión no usa otra versión, un perfil no usa otro perfil, y `:shared` no usa una versión. Las excepciones conscientes viven en su whitelist, con motivo |

## Extensión: Agregar Nuevo Módulo

1. **Identificar dependencias**: ¿qué necesita al CARGARSE (constantes, clases que engancha) y qué solo al
   ejecutarse?
2. **Colocarlo en el manifest** después de todo lo que necesita al cargarse.
3. **Añadir la línea** a `core/manifest.rb` (o al del perfil). Sin esa línea el módulo no carga en ninguna
   parte, y `manifest_check.rb` lo dirá.

## Diagnóstico de Problemas

Si un módulo no se carga:

```bash
# boot.rb escribe a #{PokeAccess::Paths::DATA}/loader_error.txt (la carpeta de datos resuelta,
# que puede ser AppData si el juego es de solo lectura). Antes de que Paths cargue, cae a
# accessibility/data/loader_error.txt.
$ cat accessibility/data/loader_error.txt

mi_modulo/mi_modulo.rb: NoMethodError: undefined method 'speak' for PokeAccess:Module
  # Significa: mi_modulo usó PokeAccess.speak al cargarse
  # Pero speech/speech aún no se había cargado
  # SOLUCIÓN: mover mi_modulo más abajo en el manifest
```

---

Volver a [Índice](12_INDEX.md)
