# Índice: buscar algo concreto

Este documento es para **buscar**: por tema, por archivo del código, por nombre de módulo o por término. Si lo que quieres es una ruta de lectura, ve a [13_READING_GUIDE](13_READING_GUIDE.md); si quieres el catálogo comentado de la documentación, a [_index](_index.md).

## Por tema

- **Cómo entra el mod en el juego** → [09_LOADING_SYSTEM](09_LOADING_SYSTEM.md)
- **Cómo se engancha a un método del juego** → [04_PATCHING_AND_HOOKS](04_PATCHING_AND_HOOKS.md)
- **Versiones de Essentials y forks** → [03_ENGINE_DETECTION](03_ENGINE_DETECTION.md)
- **Leer datos (especies, movimientos, objetos)** → [05_DATA_API](05_DATA_API.md)
- **Hablar y traducir** → [15_SPEECH_AND_I18N](15_SPEECH_AND_I18N.md)
- **Rutas y guía** → [06_PATHFINDING](06_PATHFINDING.md)
- **Sonido posicional** → [07_AUDIO3D](07_AUDIO3D.md)
- **Opciones del jugador** → [16_CONFIG_MENU](16_CONFIG_MENU.md)
- **Añadir un lector, un puzzle o un perfil** → [14_EXTENDING](14_EXTENDING.md)
- **Restricción de Ruby 1.8.7** → [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md) §1
- **Orden de carga y dependencias** → [11_DEPENDENCIES_TREE](11_DEPENDENCIES_TREE.md)
- **Diagnosticar una pantalla muda** → [14_EXTENDING](14_EXTENDING.md) §8, y el diag de [02_ARCHITECTURE](02_ARCHITECTURE.md)
- **Rendimiento** → [06_PATHFINDING](06_PATHFINDING.md) y [02_ARCHITECTURE](02_ARCHITECTURE.md)

## Por carpeta del repositorio

- `core/` — el motor del mod, agnóstico al juego → [02_ARCHITECTURE](02_ARCHITECTURE.md)
- `games/<juego>/` — perfil de un fangame: sus lectores y constantes → [14_EXTENDING](14_EXTENDING.md)
- `games/catalog.json` — la lista de perfiles y cómo se reconoce cada juego (la usan el instalador y el launcher)
- `loader/` — `preload_access.rb` (entra con mkxp-z) y `boot.rb` (carga por manifest) → [09_LOADING_SYSTEM](09_LOADING_SYSTEM.md)
- `lang/es.txt`, `lang/en.txt` — todo lo que el mod dice → [15_SPEECH_AND_I18N](15_SPEECH_AND_I18N.md)
- `assets/sounds/` — los sonidos del sonar y las señales → [07_AUDIO3D](07_AUDIO3D.md)
- `assets/x86/`, `assets/x64/` — las bibliotecas nativas por arquitectura
- `native/` — fuente C del audio 3D (`pa3d_steam.c` → `PA3D_steam.dll`) → [07_AUDIO3D](07_AUDIO3D.md)
- `bridge/` — fuente C del puente con prism (`prism_pea.c` → `prism_pea.dll`) → [15_SPEECH_AND_I18N](15_SPEECH_AND_I18N.md)
- `installer/` — los scripts de instalación y desinstalación → [README](../README.md)
- `test/` — la batería de tests (ver abajo)

## Por módulo de `core/`

### `foundation/` — la base

- `config.rb` — `SCHEMA`: cada opción del mod en una fila (clave, valor por defecto, tipo, grupo, etiqueta, ayuda). También las teclas por defecto → [16_CONFIG_MENU](16_CONFIG_MENU.md)
- `const.rb` — `PokeAccess.const_at`, `ivar`, `ivar_i`, `sprite`: las primitivas de introspección seguras en 1.8.7 → [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md) §9
- `engine.rb` — era del motor, versión, fork y `Engine.has?` → [03_ENGINE_DETECTION](03_ENGINE_DETECTION.md)
- `game.rb` — la DSL `PokeAccess::Game.define` con la que un perfil se enchufa → [14_EXTENDING](14_EXTENDING.md)
- `i18n.rb` — `I18n.t(:clave)` sobre las tablas de `lang/` → [15_SPEECH_AND_I18N](15_SPEECH_AND_I18N.md)
- `settings.rb` — persistencia de los ajustes del jugador en `settings.ini`
- `paths.rb` — dónde vive cada cosa dentro de la carpeta `accessibility/` del juego
- `events.rb` — bus de eventos en proceso (`Events.on` / `Events.emit`)
- `caches.rb` — registro de estado invalidable (se resetea al cambiar de mapa)
- `tags.rb` — etiquetas del jugador sobre objetos del mapa (renombrar, recategorizar, ocultar)
- `map_names.rb` — nombres de mapa puestos por el jugador
- `clipboard.rb` — copiar al portapapeles lo que es incómodo de escuchar
- `perf.rb` — perfilador ligero de los enganches por frame; se lee desde el diagnóstico

### `input/` — teclas y enganches

- `hooks.rb` — `before_hook`, `after_hook`, `around_hook`, `frame_hook`, `wrap_global`, `wrap_kernel` → [04_PATCHING_AND_HOOKS](04_PATCHING_AND_HOOKS.md)
- `keyboard.rb` — el teclado físico y nada más: estado crudo de una tecla y detección de flanco, vía `GetAsyncKeyState`
- `focus.rb` — si la ventana del juego está en primer plano (a prueba de fallos: ante la duda, sí)
- `input.rb` — `PokeAccess::Keys`: el orquestador. Mod activo o no, poll global por frame, ventanas de supresión mientras se escribe, y el registro de pollers por frame
- `remap.rb` — remapeo de los controles del propio juego
- `diag.rb` — la mitad diagnóstica de `Keys`: el volcado de `Ctrl`+`Alt`+`F9`, el diagnóstico hablado de `Ctrl`+`Alt`+`F10` y las secciones que los componen

### `speech/` — la voz

- `speech.rb` — `PokeAccess.speak`, `speak_clean`, braille y el puente con prism → [15_SPEECH_AND_I18N](15_SPEECH_AND_I18N.md)
- `text.rb` — `PokeAccess.clean`: quita los códigos de control de RPG Maker antes de hablar
- `markers.rb` — `write_marker` y `log_once`: dejar rastro de un error sin repetirlo mil veces

### `data/` — datos del juego

- `data.rb` — la fachada agnóstica y el registro de providers → [05_DATA_API](05_DATA_API.md)
- `data_fallback.rb` — provider de emergencia, siempre presente
- `gen6/data_g6.rb`, `v21/data_v21.rb` — los providers de cada era

### `nav/` — navegación

- `pathfinder.rb` — A* con montículo, saltos de desnivel, deslizamiento en hielo, variantes JPS/HPA* y flood de alcanzables → [06_PATHFINDING](06_PATHFINDING.md)
- `locator.rb` — el estado del locator: lista de objetivos por categoría, selección y lectura, y el poll de cada frame en el mapa
- `locator_naming.rb` — identificar y nombrar los eventos del mapa
- `locator_surfaces.rb` — las superficies del terreno como objetivos
- `guide.rb` — el bastón: un sonido que apunta al siguiente paso de la ruta
- `terrain.rb` — consultas de terreno normalizadas entre eras
- `region_map.rb` — mapa de región y viaje rápido

### `audio/` — sonido

- `audio3d.rb` — el motor de audio: maneja `PA3D_steam.dll` (Steam Audio HRTF) → [07_AUDIO3D](07_AUDIO3D.md)
- `spatial.rb` — pasos y choques con pared, panoramizados
- `glossary.rb` — el catálogo de señales que el menú del mod deja escuchar y explicar

### `menus/`, `battle/`, `party/`, `field/`, `dialogue/`, `puzzles/` — los lectores

- `menus/cursor.rb` — la primitiva de deduplicación: hablar solo cuando el foco cambia de verdad
- `menus/scene_watcher.rb` — para pantallas con su propio bucle de entrada, que hay que sondear cada frame
- `menus/menus.rb` — ventanas de comandos
- `menus/config_menu.rb` — el menú hablado del mod → [16_CONFIG_MENU](16_CONFIG_MENU.md)
- `battle/battle.rb` — la lógica hablada del combate (mensajes, comandos, PS, terreno); los enganches de cada era viven en `gen6/`, `v21/`, `v22/`, `skyflyer/`
- `battle/move_info.rb` — el formato único de un movimiento (tipo, potencia, precisión, PP, descripción)
- `battle/scene_reader.rb` — lector agnóstico de los menús de `Battle::Scene`
- `party/` — equipo, cajas del PC y pantalla de resumen
- `field/contextual.rb` — `PokeAccess::Info`: qué debe leer la tecla de información
- `dialogue/dialogue.rb` — recuerda el último diálogo para poder repetirlo
- `puzzles/puzzles.rb` — el ayudante de puzzles → [14_EXTENDING](14_EXTENDING.md) §4

### `util/` — utilidades transversales

- `kv_file.rb` — el único parser de los archivos `clave=valor` del mod (tablas de idioma, `settings.ini`, `map_names.txt`, `tags.txt`)
- `recorder.rb` — el grabador de sesiones: transcribe lo que el mod vio y dijo, para adjuntarlo a un reporte
- `text.rb` — unir partes en una línea hablada saltándose las vacías
- `player.rb` — formatos compartidos de datos del jugador (tiempo de juego, etc.)
- `grouping.rb` — `Util.union_groups`: agrupar por vecindad; lo usan el locator y el audio 3D para no repetir un mismo grupo de objetos

## Tests

- `test/run_all.rb` — el runner: corre las suites en los dos motores y luego las comprobaciones estáticas
- `test/unit/`, `test/behavior/` — las suites
- `test/static/` — comprobaciones sobre el árbol: manifests, paridad y referencias de las tablas de idioma, detección de `catalog.json`, acoplamiento entre módulos
- `test/check187.py` — comprobación de compatibilidad con Ruby 1.8.7 por patrones → [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md) §1
- `test/check187_real.rb` — la misma comprobación, pero parseando con un intérprete 1.8.7 real
- `test/bench/pathfinder_bench.rb` — medición de rendimiento del pathfinder

## Por nombre

- `PokeAccess.speak` / `speak_clean` / `clean` → [15_SPEECH_AND_I18N](15_SPEECH_AND_I18N.md)
- `PokeAccess.const_at` / `ivar` / `ivar_i` / `sprite` → [08_RUBY_FUNDAMENTALS](08_RUBY_FUNDAMENTALS.md) §9
- `PokeAccess::Audio3D` → [07_AUDIO3D](07_AUDIO3D.md)
- `PokeAccess::Config` → [16_CONFIG_MENU](16_CONFIG_MENU.md)
- `PokeAccess::Data` → [05_DATA_API](05_DATA_API.md)
- `PokeAccess::Engine` (`kind`, `version`, `fork`, `has?`) → [03_ENGINE_DETECTION](03_ENGINE_DETECTION.md)
- `PokeAccess::Events` → [10_API_REFERENCE](10_API_REFERENCE.md)
- `PokeAccess::Game.define` → [14_EXTENDING](14_EXTENDING.md)
- `PokeAccess::Hooks` → [04_PATCHING_AND_HOOKS](04_PATCHING_AND_HOOKS.md)
- `PokeAccess::I18n` → [15_SPEECH_AND_I18N](15_SPEECH_AND_I18N.md)
- `PokeAccess::Keys` (teclas del mod) → [10_API_REFERENCE](10_API_REFERENCE.md)
- `PokeAccess::Locator` → [06_PATHFINDING](06_PATHFINDING.md)
- `PokeAccess::Pathfinder` → [06_PATHFINDING](06_PATHFINDING.md)
- `PokeAccess::Tags` → [10_API_REFERENCE](10_API_REFERENCE.md)

La lista completa de métodos está en [10_API_REFERENCE](10_API_REFERENCE.md).

## Glosario

- **Gen-6** — la era de Essentials v16-v17: clases `PokeBattle_Scene`/`PScreen_*`, datos en tablas `PB*`, **Ruby 1.8.7**.
- **Era GameData** — Essentials v18 en adelante: los datos se piden a `GameData::*`.
- **Fork** — una variante de Essentials que mezcla eras; por ejemplo el de La Base de Sky, con la interfaz de v22 sobre una base v21.1.
- **Capacidad** — lo que el código pregunta en vez de la versión: "¿existe esta clase / este método?" (`Engine.has?`).
- **Provider** — el adaptador que resuelve datos en una era concreta. Gana el de mayor prioridad presente.
- **Hook (enganche)** — envolver un método del juego sin editar su archivo.
- **Manifest** — la lista ordenada de módulos que el boot carga; el orden es el de dependencias.
- **Preload** — el script que mkxp-z ejecuta antes que los scripts del juego, la puerta de entrada del mod.
- **Locator** — la lista de objetivos del mapa que el jugador recorre y selecciona.
- **Emisor** — una fuente de sonido posicional del sonar (una persona, una puerta, el agua...).
- **Oclusión** — el amortiguado del sonido cuando hay una pared por medio.
- **HRTF** — la función que hace que un sonido se perciba con dirección; es lo que da el audio binaural.
- **prism** — la biblioteca que habla con el lector de pantalla (NVDA, JAWS, SAPI, UIA, ZDSR y más).
- **mkxp-z** — el intérprete de RGSS que ejecuta el juego y admite el preload del mod.
