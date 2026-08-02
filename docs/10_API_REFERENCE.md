# API Reference - Referencia Rápida de Métodos

Consulta rápida de los métodos principales de PokeEssentialsAccess. Todo es 1.8.7-safe.

## PokeAccess: voz

**Ubicación**: `core/speech/speech.rb`. La voz sale por prism (que a su vez conduce NVDA, JAWS, SAPI, UIA,
ZDSR...) a través del puente `prism_pea.dll`; el texto va en UTF-8 directo.

```ruby
PokeAccess.speak(text, interrupt = true)
# Habla el texto. interrupt: true corta la voz en curso, false encola.
# Normaliza espacios, ignora el vacío, guarda last_spoken y notifica a on_speak.

PokeAccess.speak_clean(text, interrupt = true)
# clean(text) + speak. La forma correcta para texto que viene del JUEGO (trae códigos de RPG Maker);
# una línea ya limpia (una clave i18n resuelta) usa speak directo.

PokeAccess.clean(text)
# Quita los códigos de control de RPG Maker (\PN sustituido por el nombre del jugador, \V[n] por la
# variable, \C[n], \N, etiquetas <b>...) y los bytes de control. Devuelve texto hablable.

PokeAccess.stop_speech          # Silencia al lector ya, sin decir nada nuevo. true si el backend obedeció.
PokeAccess.pause_speech         # Pausa la voz en curso. Depende del backend (SAPI y UIA sí, NVDA no):
PokeAccess.resume_speech        # false significa "no soportado o nada que hacer", nunca un error.

PokeAccess.speaking?
# true / false / nil. nil = NO SE SABE (el backend no puede decirlo). Trata nil como desconocido,
# NUNCA como silencio.

PokeAccess.braille(text)
# Envía texto a la pantalla braille activa (UTF-8, como speak). false si no hay ninguna.

PokeAccess.braille_codepoints(cps)
# Igual con un array de codepoints unicode (p.ej. celdas de patrón braille U+28xx). Solo BMP.

PokeAccess.speech_backend
# Nombre del backend activo ("NVDA", "JAWS", "SAPI 5"...) para el diagnóstico, o "" si está caído.

PokeAccess.speech_ready?
# ¿Se levantó el puente? Lo lee el diagnóstico; un lector normal no lo necesita.

PokeAccess.on_speak = lambda { |text, interrupt| ... }
PokeAccess.on_speak
# Observador ÚNICO de todo lo hablado (nil por defecto). Es el punto de extensión del grabador de
# sesión: transcribe una partida sin un solo hook dentro de los lectores. Un observador que lanza se
# ignora (un instrumento nunca puede silenciar al mod).

PokeAccess.last_spoken
# Última línea hablada (para el diagnóstico hablado), o nil.
```

## PokeAccess: utilidades

```ruby
PokeAccess.const_at("A::B::C")
# Resuelve una constante anidada por nombre, 1.8.7-safe (o nil). La usan Hooks/Input/Menus/Engine.has?
# Es para cuando quieres la CONSTANTE. Para el booleano "¿existe?" la puerta única es Engine.has?

PokeAccess.ivar(obj, :@index, fallback = nil)
# Lee un ivar de cualquier objeto de forma defensiva; devuelve fallback si no existe o falla
# (los objetos del motor no exponen accessors y el ivar varía por versión).

PokeAccess.ivar_i(obj, :@index, fallback = 0)
# Igual pero forzando a Integer (para ivars numéricos).

PokeAccess.sprite(scene, "commandwindow")
# Un sprite del hash @sprites de una escena, o nil si el hash o la clave faltan.

PokeAccess.write_marker(msg)
# Escribe una línea de diagnóstico al marker.

PokeAccess.log_once(key, error)
# Registra un error una sola vez por clave (evita spam por-frame).

PokeAccess.format_error(e)
# Formatea una excepción (clase, mensaje y traza recortada) para el marker.

PokeAccess.clock
# Segundos de reloj de pared desde que cargó el mod. Única fuente del ritmo de las señales (pings del
# sonar, chime de guía, cooldown de choque, perfilador). NO usa System.uptime ni Graphics.frame_count:
# el mkxp-z de Infinite Fusion devuelve un System.uptime que no son segundos (todo el sonar disparado a
# ritmo de frame) y frame_count sólo mide tiempo mientras el juego mantenga su tasa nominal, además de
# saltar al cargar partida. Los pasos NO pasan por aquí: suenan al cambiar de casilla, así que siguen
# al jugador aunque acelere con el turbo.
```

## PokeAccess::Engine

**Ubicación**: `core/foundation/engine.rb`. Distingue la era gen-6 (tablas `PB*`) de la era GameData.

```ruby
PokeAccess::Engine.gamedata?   # true si existe la capa GameData (Essentials v17+)
PokeAccess::Engine.gen6?       # el opuesto
PokeAccess::Engine.kind        # :gamedata o :gen6

PokeAccess::Engine.player      # $player (era GameData) o $Trainer (gen-6)

PokeAccess::Engine.version     # Float comparable: 16.0, 19.0, 21.1, 22.0...
PokeAccess::Engine.fork        # :sky o nil
# version y fork son SOLO para la línea del diagnóstico: los fangames reales mezclan eras (v18 con
# backports, Sky es v21.1 con la UI de v22), así que el código nunca debe gatear por el número.
```

### `Engine.has?` — la puerta única de capacidad

```ruby
PokeAccess::Engine.has?(cap)
# Admite tres formas:
PokeAccess::Engine.has?(:ui_rework)                              # símbolo registrado
PokeAccess::Engine.has?("UI::PokedexEntryVisuals")               # nombre de clase (1.8.7-safe)
PokeAccess::Engine.has?("Battle::Scene::MenuBase#setIndexAndMode") # clase + método de instancia
```

Los lectores gatean por **capacidad**, nunca por versión: así un fork que backportee un método (o una
versión futura que lo conserve) se activa solo. Las carpetas `v21/`, `v22/`... dicen DÓNDE apareció la
capacidad; la activación la decide `has?`.

Capacidades registradas (`Engine::CAPABILITIES`):

| Símbolo | Prueba |
|---|---|
| `:gamedata` / `:gen6` | La era del motor |
| `:sky_fork` | El fork Sky |
| `:ui_rework` | `UI::BaseScreen` (el rework de UI de v22) |
| `:battle_scene` | `Battle::Scene` (la escena de combate de v19+) |

Una pantalla concreta no necesita registro: pásale su nombre de clase a `has?` directamente.

## PokeAccess::Hooks

**Ubicación**: `core/input/hooks.rb`. Detalle completo y la guarda de reentrancia en
[04_PATCHING_AND_HOOKS.md](04_PATCHING_AND_HOOKS.md).

```ruby
PokeAccess::Hooks.before_hook(cname, meth, opts = {}) { |obj, args| ... }
# Corre el cuerpo ANTES del original (para hablar antes de que bloquee). El cuerpo puede mutar args
# in situ. El original corre SIN guarda de reentrancia.

PokeAccess::Hooks.after_hook(cname, meth, opts = {}) { |obj, result, args| ... }
# Corre el cuerpo DESPUÉS, con el resultado del original. Por defecto el original corre BAJO la guarda
# de reentrancia (es un anunciante atómico).

PokeAccess::Hooks.around_hook(cname, meth, opts = {}) { |obj, call_next, args| ... }
# Control total: llama call_next para ejecutar el resto de la cadena y el original, o no lo llames para
# sustituirlo. call_next NO toma argumentos (replay con los del llamante); para cambiarlos, muta args.
# Devuelve lo que devuelva el cuerpo. Su fallo NO se traga: se loguea y se relanza.

PokeAccess::Hooks.frame_hook(cname, meth) { |obj, args| ... }
# After-hook para un DRIVER por-frame que puede alojar un bucle modal entero (Game_Player#update).
# Corre el original SIN guarda y el cuerpo después; un poller no usa el valor de retorno.

PokeAccess::Hooks.read_on_open(cname, meth = :pbStartScene, opts = {}) { |scene| texto }
# Habla el resumen de apertura de una pantalla, ENCOLADO (una lectura de apertura nunca interrumpe) y
# limpiado con clean. nil o vacío no habla. opts[:timing] => :before para abridores que BLOQUEAN en su
# propio bucle (con un after solo hablarían al cerrar). :optional y :hook_container pasan al hook.

PokeAccess::Hooks.override(target, meth, opts = {}) { |receiver, original, args| ... }
# REEMPLAZO declarado. target: un módulo del mod (sustituye su método de singleton) o el nombre en
# string de una clase del juego (sustituye su método de instancia). original es un lambda con la
# implementación reemplazada: llámalo para ENVOLVER en vez de sustituir. Semántica de around (el fallo
# se loguea y se relanza). Apilable: un segundo override recibe el primero como original; gana el
# último y ambos quedan listados. opts[:tag] nombra al dueño en el listado.

PokeAccess::Hooks.wrap_global(name, tag, timing = :after) { |args, x| ... }
# Envuelve un método top-level (de Object) que los hooks de clase no alcanzan (pbDisplayMail...).

PokeAccess::Hooks.wrap_kernel(name, tag, timing = :before) { |args, x| ... }
# Igual, pero prueba primero el singleton de Kernel (def Kernel.foo, estilo gen-6) y cae a wrap_global
# (def foo, estilo moderno) — pbShowCommandsWithHelp o pbDisplayText varían así según el juego.
# timing :before -> x=nil ; :after -> x=resultado ; :around -> x=call_next (lo llamas tú).

PokeAccess::Hooks.wrap(cname, meth, opts = {}) { |obj, call_next, args| ... }
# El motor: registra un middleware crudo en la cadena. Los demás registradores son capas sobre él.
```

### Opciones

| Opción | Efecto |
|---|---|
| `:optional => true` | El método **falta legítimamente** en algunos juegos: el enganche se salta en silencio en vez de contar como typo en `Hooks.missing` |
| `:hook_container => true` | El método es un **contenedor** (bucle modal o abridor de escena) que delega el anuncio en métodos hookeados que él conduce: su original corre SIN la guarda de reentrancia |

Una **clase** ausente siempre es no-op silencioso (variación normal entre juegos).

### Diagnóstico

```ruby
PokeAccess::Hooks.missing
# Array de "Clase#metodo" cuya CLASE existe pero el MÉTODO no (y no era :optional). PROBABLE TYPO.

PokeAccess::Hooks.fn_absent
# Nombres de función global que wrap_global/wrap_kernel no encontraron EN NINGÚN SITIO (ni singleton de
# Kernel ni Object). Informativo: que una función solo exista en algunos fangames es normal.

PokeAccess::Hooks.overrides
# Los reemplazos instalados, como "Target.meth (tag)". El diagnóstico los imprime, así que pisar un
# lector del core nunca es invisible.
```

## PokeAccess::Cursor

**Ubicación**: `core/menus/cursor.rb`. La primitiva de dedup **por defecto** para lecturas de
cursor/selección: la UI re-afirma el foco cada frame, así que un lector debe hablar solo cuando cambia de
verdad. Todo lector nuevo la usa en lugar de abrir un ivar `@access_*` propio. La única excepción tolerada
es el hook que **ya recibe por `args` el dato que compara** (el índice o la clave llegan como argumento
del método enganchado): ahí el dedup a mano es local al hook y basta un ivar con el valor anterior.

```ruby
PokeAccess::Cursor.changed?(holder, slot, key)
# true (y guarda la key) si difiere de lo último que slot guardó en holder. Una key nil cuenta SIEMPRE
# como "sin cambio" (un valor ausente nunca habla). Úsalo para gatear trabajo arbitrario.

PokeAccess::Cursor.on_change(holder, slot, key) { ... }
# Corre el bloque solo si cambió y devuelve su valor; si no, nil. La línea se calcula perezosamente.

PokeAccess::Cursor.announce(holder, slot, key, interrupt = true, first_interrupt = nil) { texto }
# El caso común: al cambiar el cursor, habla la línea que construye el bloque (limpiada con clean, e
# interrumpiendo por defecto). No hace nada si la línea es nil o vacía.
# first_interrupt: valor de interrupt para la PRIMERA lectura de un cursor fresco o reseteado (cuando
# el slot está pending?), para el patrón "encola la lectura de apertura, interrumpe en los movimientos
# siguientes". nil (por defecto) usa interrupt siempre.

PokeAccess::Cursor.pending?(holder, slot)
# true en la PRIMERA lectura de un cursor fresco/reseteado (el slot aún no guarda key). Se consulta
# ANTES del changed? que registra la key.

PokeAccess::Cursor.reset(holder, slot)
# Limpia el slot: la siguiente lectura habla aunque la key no haya cambiado. Llámalo al (re)abrir una
# pantalla cuyo cursor puede estar en la misma entrada que la vez anterior.
```

- **`holder`** = la escena/instancia: el estado de dedup vive EN ella (un ivar compuesto
  `@access_cur_<slot>`), así que muere con la escena y al reabrir vuelve a leer. `nil` usa una tabla
  global por slot, para lectores sin instancia donde colgarse.
- **`slot`** = un símbolo propio de ese lector, en crudo (`:mi_lista`); dos lectores sobre la misma
  escena nunca se pisan. Un `@` inicial heredado se tolera y se descarta.
- **`key`** = un índice, un texto o una tupla (`[página, índice_de_party]`).

## PokeAccess::SceneWatcher

**Ubicación**: `core/menus/scene_watcher.rb`. Para pantallas que corren **su propio bucle de entrada
bloqueante**: los hooks de cursor no disparan a mitad del bucle y hay que sondear el foco por frame.
Sujeta la escena viva mientras dura el método del bucle (con un `around`) y corre el poll cada frame.

```ruby
PokeAccess::SceneWatcher.wire(cls, meth, reader)
# La plomería. cls/meth: la clase de la escena y su método de bucle bloqueante; reader: un módulo que
# responde a watch(scene), unwatch y poll. Se auto-gatea por existencia de la clase (no-op en juegos
# que no la tienen). unwatch corre en un ensure: un bucle que lanza no deja el lector colgado.

holder = PokeAccess::SceneWatcher.reader(cls, meth, slot) { |scene| [key, texto] }
# La forma de UNA llamada para la figura habitual: sujeta la escena, la sondea cada frame, deduplica
# por key y habla al cambiar (limpiado, interrumpiendo).
#   - el bloque devuelve [key, texto]; nil (o algo que no sea par) salta el frame
#   - texto puede ser un lambda: entonces SOLO se invoca si la key cambio. El cursor se queda quieto, asi
#     que 39 de cada 40 frames la key coincide y el texto construido se tira sin leerse: gratis para
#     "#{nombre}", nada gratis para un lector que le pregunta algo al juego para redactarse
#   - una key nil nunca habla (contrato de Cursor); una key real con texto vacío la consume en silencio
#   - el dedup vive en un slot de Cursor sobre un holder generado, reseteado al abrir Y al cerrar, así
#     que reabrir en la misma entrada vuelve a leer
#   - un bloque que lanza se traga por frame (un bug de lector no puede matar el bucle de entrada)
# Devuelve el holder, por si necesitas más hooks sobre el mismo estado. Los bloques usan next, no
# return (define_method bajo 1.8.7).
```

Usa `wire` directamente cuando tu módulo se desvía de la figura (tiene su propio ritmo de habla o una
API extra).

## PokeAccess::Game

La DSL declarativa con la que un perfil de juego se enchufa al toolkit (`core/foundation/game.rb`). Cada
método es una capa fina sobre las llamadas crudas de arriba. Referencia completa en
[14_EXTENDING.md](14_EXTENDING.md).

```ruby
PokeAccess::Game.define("<juego>") do
  after("MiScene", :selectButton) { |scene, _ret, args| ... }
end

PokeAccess::Game.profiles   # identificadores de los perfiles definidos (diagnóstico)
```

## PokeAccess::Config

```ruby
PokeAccess::Config.language
PokeAccess::Config.auto_guide
PokeAccess::Config.hide_unreachable
PokeAccess::Config.audio3d_volume
PokeAccess::Config.route_reach
# Lectura de configuración

PokeAccess::Config.language = :es
# Establecer configuración

PokeAccess::Config.schema_group(:pathfinder)
# Las filas del esquema de un grupo (para el menú de opciones)

PokeAccess::Config.rebind_labels
# Hash de etiquetas de botones del menú de remap (un perfil le hace merge!)
```

## PokeAccess::Caches

```ruby
PokeAccess::Caches.register(:name) { ... }  # registra un reset de estado por-run (idempotente por nombre)
PokeAccess::Caches.reset_all                # corre todos, cada uno guardado (se dispara en :map_changed)
PokeAccess::Caches.names                    # nombres registrados (diagnóstico)
```

## PokeAccess::Data

```ruby
PokeAccess::Data.species_name(id)           # "Pikachu"
PokeAccess::Data.species_entry(id)          # Entrada de la pokédex
PokeAccess::Data.move_name(id)              # "Tackle"
PokeAccess::Data.move_type_name(id)         # "Normal"
PokeAccess::Data.move_power(id)             # 40
PokeAccess::Data.move_accuracy(id)          # 100
PokeAccess::Data.move_description(id)       # "Atacar..."
PokeAccess::Data.type_name(id)              # "Fire"
PokeAccess::Data.item_name(id)              # "Potion"
PokeAccess::Data.item_name_plural(id)       # "Potions"
PokeAccess::Data.item_description(id)       # "Recupera 20 PS..."
PokeAccess::Data.item_id(symbol)            # :POTION -> 1
PokeAccess::Data.ability_name(id)           # "Static"
PokeAccess::Data.nature_name(id)            # "Timid"
PokeAccess::Data.stat_name(stat)            # "Atk"
PokeAccess::Data.status_name(status)        # "Poison"
PokeAccess::Data.pokemon_types(pokemon)     # [:fire, :flying]
# Todos pasan por resolve: nil-safe, y una excepción del proveedor se registra en vez de propagarse.

PokeAccess::Data.register(priority, provider)  # registrar un proveedor de datos
PokeAccess::Data.active                        # proveedor activo
PokeAccess::Data.active_priority               # 20 GameData, 10 gen-6, 0 fallback
PokeAccess::Data.errors                        # errores del proveedor
```

## PokeAccess::Battle

```ruby
PokeAccess::Battle.hp_phrase(hp, tot, as_percent)
# Frase de PS: porcentaje (as_percent true, para un rival o una barra oculta) o "hp/total" exacto.
# Centraliza el branch y la guarda de división por cero.

PokeAccess::Battle.set_battle(b)
# Captura el objeto batalla en curso, para que las teclas de PS/campo puedan leerlo.
```

## PokeAccess::MoveInfo

```ruby
PokeAccess::MoveInfo.by_id_via_data(id)
# Detalle hablado de un movimiento por id, resuelto vía el adaptador Data por-motor (PBMoveData en
# gen-6, GameData en moderno), no GameData directo, para que un lector gen-6 obtenga la línea completa.
# nil si el id no resuelve.

PokeAccess::MoveInfo.line(name, type_name, power, accuracy, opts = {})
# Ensambla "nombre. tipo. poder. precisión[. pp][. descripción]" desde partes ya resueltas.
# Opciones: :pp y :total_pp (ambas para hablar pp), :desc (se añade si no está en blanco).
```

## PokeAccess::Pathfinder

```ruby
PokeAccess::Pathfinder.find_path(tx, ty)
# Ruta al destino (tx, ty); el origen es $game_player. Array de [x, y], o nil si no hay ruta

PokeAccess::Pathfinder.reachable_set        # hash de tiles alcanzables desde el jugador
PokeAccess::Pathfinder.reach                # distancia máxima de alcance (Config.route_reach)
PokeAccess::Pathfinder.invalidate_cache(force = false)   # limpiar caché de rutas
PokeAccess::Pathfinder.passable_at?(x, y, direction)     # ¿se puede mover en esa dirección?
PokeAccess::Pathfinder.ledge_jump(cx, cy, dx, dy, d)     # ¿hay salto de ledge? tile de aterrizaje o nil
```

## PokeAccess::Audio3D

```ruby
PokeAccess::Audio3D.boot            # inicializa el audio 3D (idempotente: dll y canales una sola vez)
PokeAccess::Audio3D.device_rate     # frecuencia del device (44100 o 48000 Hz)
PokeAccess::Audio3D.device_latency  # latencia del device en ms
PokeAccess::Audio3D.range           # rango de detección de emisores (tiles)
PokeAccess::Audio3D.occlusion_mode  # :hear, :occlude o :hide
PokeAccess::Audio3D.wav(name)       # ruta correcta del .wav según la frecuencia del device
```

## PokeAccess::Events

```ruby
PokeAccess::Events.on(name) { |*args| ... }  # suscribirse (corren en orden de suscripción, guardados)
PokeAccess::Events.emit(name, *args)         # emitir a todos los suscriptores

# Eventos emitidos por el core:
PokeAccess::Events.on(:map_changed) { |map_id| ... }   # cambio de mapa (también tras cargar partida)
PokeAccess::Events.on(:tags_changed) { ... }           # el jugador editó etiquetas de objetos
```

## PokeAccess::Tags

```ruby
PokeAccess::Tags.get(map_id, event_id)                  # nombre personalizado, o nil
PokeAccess::Tags.set(map_id, event_id, label)           # establecer nombre personalizado
PokeAccess::Tags.category(map_id, event_id)             # categoría override (:people, :objects...) o nil
PokeAccess::Tags.set_category(map_id, event_id, symbol) # establecer categoría
PokeAccess::Tags.hidden?(map_id, event_id)              # ¿está oculto?
PokeAccess::Tags.set_hidden(map_id, event_id, true)     # ocultar/mostrar
PokeAccess::Tags.remove(map_id, event_id)               # borrar toda la información del evento
```

## PokeAccess::Locator

```ruby
PokeAccess::Locator.rebuild_targets      # reconstruye la lista de objetivos de la categoría actual
PokeAccess::Locator.cycle_category(dir)  # cambia de categoría (+1/-1: personas/objetos/salidas/...)
PokeAccess::Locator.step(delta)          # avanza/retrocede en la lista de objetivos (+1/-1)
PokeAccess::Locator.select_current       # selecciona el objetivo enfocado y traza la ruta
PokeAccess::Locator.announce_selected(withname)  # dice el objetivo seleccionado
PokeAccess::Locator.announce_route       # dice la ruta hacia el objetivo seleccionado
PokeAccess::Locator.announce_coords      # dice las coordenadas/posición del jugador
PokeAccess::Locator.toggle_hide_unreachable  # alterna el filtro de objetivos inalcanzables
PokeAccess::Locator.rename_map           # pide un nombre personalizado para el mapa y lo persiste
PokeAccess::Locator.map_poll             # trabajo por frame del localizador (lo llama el driver por-frame)
PokeAccess::Locator.show_menu(msg, choices, cancel)  # menú de elección genérico
PokeAccess::Locator.tag_menu             # abre el menú de etiquetado/categorías del objetivo
PokeAccess::Locator.register_hazard(pattern, label)  # sprite de peligro con etiqueta + cue
```

## PokeAccess::Terrain

```ruby
PokeAccess::Terrain.label(x, y)          # símbolo de terreno (:surf_water, :tree...)
PokeAccess::Terrain.ledge_at?(x, y)      # ¿hay un ledge (saliente)?
PokeAccess::Terrain.surfable_at?(x, y)   # ¿se puede surfear ahí?
PokeAccess::Terrain.grass?(t) / .ice?(t) / .bridge?(t)
# Predicados sobre un VALOR de terreno (el que devuelve label/raw), no coordenadas.
# Para consultar por tile existe la variante *_at?, p.ej. ice_at?(x, y).
```

## PokeAccess::Settings

```ruby
PokeAccess::Settings.read    # lee el settings.ini del usuario
PokeAccess::Settings.write   # lo escribe
PokeAccess::Settings.apply   # lee y aplica los ajustes guardados al arrancar
```

## PokeAccess::I18n

```ruby
PokeAccess::I18n.t(key, vars = {})
PokeAccess::I18n.t(:lbl_language)                 # "Idioma"
PokeAccess::I18n.t(:mv_pp, :pp => 5, :tot => 15)  # "PP: 5/15"

PokeAccess::I18n.lang                 # idioma actual (:es, :en...)
PokeAccess::I18n.available_languages  # idiomas disponibles
```

## PokeAccess::Paths

```ruby
PokeAccess::Paths::DATA    # accessibility/data (datos y diag.txt)
PokeAccess::Paths::SOUNDS  # accessibility/sounds
PokeAccess::Paths::LANG    # accessibility/lang (traducciones)
PokeAccess::Paths::LIB     # accessibility/lib (dll por arquitectura)
PokeAccess::Paths::GAME    # accessibility/game (perfil del juego)
```

## PokeAccess::Info

```ruby
PokeAccess::Info.set_info(kind, data)
# Establece el contexto que leerá la tecla de información

PokeAccess::Info.info_text
# Texto del contexto actual (lo que dice la tecla de info)

# Clases de contexto (el kind que se pasa a set_info):
:move         # movimiento seleccionado
:item         # objeto seleccionado
:pokemon      # Pokémon actual
:trainer      # el entrenador
:battle_foe   # enemigo actual en batalla
:text         # una línea ya montada (lo usa un perfil que publica su propio texto)

PokeAccess::Info.clear_combat
# Olvida el contexto de combate (:move/:battle_foe/:text) para que la tecla de info no siga leyendo
# una línea de batalla en el mapa; el contexto de campo (:pokemon/:item/:trainer) se conserva.
```

## PokeAccess::Perf

```ruby
PokeAccess::Perf.measure(label) { ... }  # mide el bloque y lo acumula bajo la etiqueta
PokeAccess::Perf.report                  # reporte de tiempos (ms promedio/máximo)
PokeAccess::Perf.reset                   # limpia los timers
```

## PokeAccess::Keys

```ruby
PokeAccess::Keys.enabled        # ¿mod habilitado? (Ctrl+Alt+F8 para alternar)
PokeAccess::Keys.raw_down?(vk)  # ¿tecla abajo? (0x77 = F8, 0x11 = Ctrl, 0x12 = Alt)
PokeAccess::Keys.global_poll    # procesa las teclas contextuales (lo llama el hook de Input#update)
PokeAccess::Keys.on_frame { ... }  # registra un bloque que corre una vez por frame en toda escena

PokeAccess::Keys.register_diag_section(name, group = :scene) { |lines| ... }
# Añade una sección propia al volcado de diagnóstico y al grupo del menú de depuración. Es lo que hay
# debajo de diag_section en la DSL de perfiles.

PokeAccess::Keys.typing!
# Llamar mientras un campo de texto está activo: suprime TODAS las teclas del mod por unos frames
# (una "t" escrita debe entrar la letra, no leer info).

PokeAccess::Keys.menu_lock!
# Llamar mientras un menú custom con su propio input crudo está activo: suprime las teclas de
# movimiento/comando del mod pero DEJA las de info de solo lectura (consultar la opción enfocada).
# Decae en unos frames, como typing!.
```

## Ejemplos de Uso

### Obtener nombre de Pokémon (versión agnóstica)
```ruby
name = PokeAccess::Data.species_name(123)   # "Scyther" en cualquier versión
```

### Crear ruta a objetivo
```ruby
# El origen es siempre $game_player; solo se pasa el destino.
path = PokeAccess::Pathfinder.find_path(target_x, target_y)
path ? "Camino: #{path.length} tiles" : "No hay ruta"
```

### Gatear por capacidad, no por versión
```ruby
if PokeAccess::Engine.has?("UI::PokedexEntryVisuals")
  PokeAccess::Hooks.after_hook("UI::PokedexEntryVisuals", :refresh) do |vis, _r, _a|
    PokeAccess::Cursor.announce(vis, :dex_entry, PokeAccess.ivar(vis, :@index)) { linea(vis) }
  end
end
```

### Registrar callback
```ruby
PokeAccess::Events.on(:map_changed) { |map_id| PokeAccess.write_marker("mapa #{map_id}\n") }
```

### Crear hook
```ruby
PokeAccess::Hooks.before_hook("MyClass", :my_method) do |obj, args|
  PokeAccess.write_marker("llamado con #{args.inspect}\n")
end
```

## Quick Lookup

| Acción | Método | Doc |
|--------|--------|-----|
| Hablar | `PokeAccess.speak()` | esta página |
| Deduplicar cursor | `PokeAccess::Cursor.announce()` | esta página |
| Hook | `PokeAccess::Hooks.*()` | [Patching & Hooks](04_PATCHING_AND_HOOKS.md) |
| Perfil de juego | `PokeAccess::Game.define()` | [Extending](14_EXTENDING.md) |
| Capacidad | `PokeAccess::Engine.has?()` | [Engine Detection](03_ENGINE_DETECTION.md) |
| Datos | `PokeAccess::Data.*()` | [Data API](05_DATA_API.md) |
| Ruta | `PokeAccess::Pathfinder.*()` | [Pathfinding](06_PATHFINDING.md) |
| Audio 3D | `PokeAccess::Audio3D.*()` | [Audio3D](07_AUDIO3D.md) |

---

Volver a [Índice](12_INDEX.md)
